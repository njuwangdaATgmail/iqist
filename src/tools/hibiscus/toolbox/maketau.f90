!!!=========+=========+=========+=========+=========+=========+=========+!
!!! HIBISCUS/toolbox/maketau @ iQIST                                     !
!!!                                                                      !
!!! This tool is used to postprocess the bins data of the imaginary time !
!!! green's function.
!!! author  : Li Huang (at IOP/CAS & SPCLab/CAEP & UNIFR)                !
!!! version : v2014.10.11T                                               !
!!! status  : WARNING: IN TESTING STAGE, USE IT IN YOUR RISK             !
!!! comment : any question, please contact with huangli712@gmail.com     !
!!!=========+=========+=========+=========+=========+=========+=========+!

!!
!!
!! Introduction
!! ============
!!
!! The maketau code is often used to convert file solver.green.bin.*
!! or solver.green.dat to tau.grn.dat, prepare input data for hibiscus/
!! entropy1 or hibiscus/stoch codes.
!!
!! Usage
!! =====
!!
!! # ./mtau or bin/mtau.x
!!
!! Input
!! =====
!!
!! solver.green.dat or solver.green.bin.* (necessary)
!!
!! Output
!! ======
!!
!! tau.grn.dat
!!
!! Documents
!! =========
!!
!! For more details, please go to iqist/doc/manual directory.
!!
!!

  program maketau
     use constants

     implicit none

!-------------------------------------------------------------------------
! local setting parameters
!-------------------------------------------------------------------------
! number of bands
     integer  :: nband = 1

! number of spin orientation
! note: do not modify it
     integer  :: nspin = 2

! number of orbitals, norbs = nspin * nband
     integer  :: norbs = 2

! number of time slice, 129 or 1024, in [0, \beta]
     integer  :: ntime = 129

! number of data bins
     integer  :: nbins = 1

! file type generated by quantum impurity solver
! if ctqmc == 1, ctqmc;
! if ctqmc == 2, hfqmc;
! if ctqmc == 3, ctqmc-bin;
! if ctqmc == 4, hfqmc-bin.
     integer  :: ctqmc = 1

! inversion of temperature
     real(dp) :: beta  = 10.0_dp
!^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

!-------------------------------------------------------------------------
! local variables
!-------------------------------------------------------------------------
! loop index
     integer  :: i
     integer  :: j

! loop index over QMC data bins
     integer  :: ibin

! dummy integer variables
     integer  :: itmp, jtmp

! status flag
     integer  :: istat

! used to check whether the input file exists
     logical  :: exists

! real(dp) dummy variables
     real(dp) :: rtmp

! current bin index, string representation
     character(len=10) :: sbin

! time slice
     real(dp), allocatable :: tau(:)

! green's function data
     real(dp), allocatable :: grn(:,:), grn_bin(:,:,:)

! error bar data
     real(dp), allocatable :: err(:,:)
!^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

! print program header
     write(mystd,'(2X,a)') 'MTAU'
     write(mystd,'(2X,a)') 'making tau-dependent imaginary time green''s function'
     write(mystd,'(2X,a)') 'version: 2011.08.18T'
     write(mystd,*) ! print blank line

! setup necessary parameters
     write(mystd,'(2X,a)')   '>>> number of bands (default = 1):'
     write(mystd,'(2X,a,$)') '>>> '
     read (mystd,'(i)') nband
     write(mystd,*)
     norbs = nband * nspin

     write(mystd,'(2X,a)')   '>>> number of time slice (default = 129 or 1024):'
     write(mystd,'(2X,a,$)') '>>> '
     read (mystd,'(i)') ntime
     write(mystd,*)

     write(mystd,'(2X,a)')   '>>> number of data bins (default = 1):'
     write(mystd,'(2X,a,$)') '>>> '
     read (mystd,'(i)') nbins
     write(mystd,*)

     write(mystd,'(2X,a)')   '>>> file type generated by quantum impurity solver (default = 1):'
     write(mystd,'(2X,a)')   'ctqmc: 1'
     write(mystd,'(2X,a)')   'hfqmc: 2'
     write(mystd,'(2X,a)')   'ctqmc: 3 (bin mode)'
     write(mystd,'(2X,a)')   'hfqmc: 4 (bin mode)'
     write(mystd,'(2X,a,$)') '>>> '
     read (mystd,'(i)') ctqmc
     write(mystd,*)

     write(mystd,'(2X,a)')   '>>> inversion of temperature (default = 10.0):'
     write(mystd,'(2X,a,$)') '>>> '
     read (mystd,  *  ) beta
     write(mystd,*)

! allocate memory
     allocate(tau(ntime),       stat=istat)

     allocate(grn(ntime,norbs), stat=istat)
     allocate(err(ntime,norbs), stat=istat)

     allocate(grn_bin(ntime,norbs,nbins), stat=istat)

! initialize variables
     exists = .false.

! initialize arrays
     tau = zero

     grn = zero
     err = zero

     grn_bin = zero

!-------------------------------------------------------------------------

! build time slice mesh
     do i=1,ntime
         tau(i) = beta * real( i - 1 ) / real(ntime - 1)
     enddo ! over i={1,ntime} loop

!-------------------------------------------------------------------------

     if ( ctqmc == 1 .or. ctqmc == 2 ) then

! inquire file status: solver.green.dat
         inquire (file = 'solver.green.dat', exist = exists)

         if ( exists == .true. ) then
             write(mystd,'(2X,a)') '>>> reading solver.green.dat ...'

! open solver.green.dat file
             open(mytmp, file='solver.green.dat', form='formatted', status='unknown')

! read green's function data
             do i=1,nband
                 do j=1,ntime
                     read(mytmp,*) itmp, jtmp, rtmp, grn(j,i), grn(j,i+nband)
                 enddo ! over j={1,ntime} loop
                 read(mytmp,*) ! skip two lines
                 read(mytmp,*)
             enddo ! over i={1,nband} loop

! close solver.green.dat file
             close(mytmp)

             write(mystd,'(2X,a)') '>>> status: OK'
             write(mystd,*)
         else
             write(mystd,'(2X,a)') 'WARNING: solver.green.dat file do not exist!'
             STOP
         endif ! back if ( exists == .true. ) block

! ensure grn is positive
         grn = abs(grn)

     endif ! back if ( ctqmc == 1 .or. ctqmc == 2 ) block

!-------------------------------------------------------------------------

     if ( ctqmc == 3 .or. ctqmc == 4 ) then
         do ibin=1,nbins

! convert ibin to sbin
             write(sbin,'(i10)') ibin

! inquire file status: solver.green.bin.ibin
             inquire (file = 'solver.green.bin.'//trim(adjustl(sbin)), exist = exists)

             if ( exists == .true. ) then
! open solver.green.bin file
                 write(mystd,'(2X,a,i4)') '>>> reading solver.green.bin ...', ibin
                 open(mytmp, file='solver.green.bin.'//trim(adjustl(sbin)), form='formatted', status='unknown')

! read green's function data
                 do i=1,nband
                     do j=1,ntime
                         read(mytmp,*) itmp, jtmp, rtmp, grn_bin(j,i,ibin), grn_bin(j,i+nband,ibin)
                     enddo ! over j={1,ntime} loop
                     read(mytmp,*) ! skip two lines
                     read(mytmp,*)
                 enddo ! over i={1,nband} loop

! close solver.green.bin file
                 close(mytmp)

                 write(mystd,'(2X,a)') '>>> status: OK'
                 write(mystd,*)
             else
                 write(mystd,'(2X,a)') 'WARNING: solver.green.bin file do not exist!'
                 STOP
             endif ! back if ( exists == .true. ) then

         enddo ! over ibin={1,nbins} loop

! ensure grn_bin is positive
         grn_bin = abs(grn_bin)

! postprocess the data bin
         do ibin=nbins,2,-1
             grn_bin(:,:,ibin) = grn_bin(:,:,ibin) * real(ibin) - grn_bin(:,:,ibin-1) * real(ibin-1)
         enddo ! over ibin={nbins,2} loop

! calculate averaged green's function
         grn = zero
         do ibin=1,nbins
             grn = grn + grn_bin(:,:,ibin)
         enddo ! over ibin={1,nbins} loop
         grn = grn / real(nbins)

! calculate standard variance
         do i=1,norbs
             do j=1,ntime
                 err(j,i) = zero
                 do ibin=1,nbins
                     err(j,i) = err(j,i) + ( grn_bin(j,i,ibin) - grn(j,i) )**2
                 enddo ! over ibin={1,nbins} loop
                 err(j,i) = sqrt( err(j,i) / real( nbins - 1 ) )
             enddo ! over j={1,ntime} loop
         enddo ! over i={1,norbs} loop
     endif ! back if ( ctqmc == 3 .or. ctqmc == 4 ) block

!-------------------------------------------------------------------------

! special treatment for ctqmc quantum impurity solver
     if ( ctqmc == 1 ) then
! smooth original data using bezier curves
         call make_bezier(ntime, norbs, tau, grn)

! interpolte green's function to new mesh using cubic spline
         call make_spline(ntime, norbs, beta, tau, grn)

! fix ntime, size of new mesh
         ntime = 129
     endif ! back if ( ctqmc == 1 ) block

!-------------------------------------------------------------------------

! open tau.grn.dat file, which is used as the input for entropy/sai program
     write(mystd,'(2X,a)') '>>> writing tau.grn.dat ...'

     open(mytmp, file='tau.grn.dat', form='formatted', status='unknown')

! write out data
     do i=1,nband
         do j=1,ntime
             write(mytmp,'(5f16.8)') tau(j), grn(j,i), err(j,i), grn(j,i+nband), err(j,i+nband)
         enddo ! over j={1,ntime} loop

! write two blank lines
         write(mytmp,*)
         write(mytmp,*)
     enddo ! over i={1,nband} loop

! close tau.grn.dat file
     close(mytmp)

     write(mystd,'(2X,a)') '>>> status: OK'
     write(mystd,*)

! deallocate memory
     deallocate(tau)

     deallocate(grn)
     deallocate(err)

     deallocate(grn_bin)

  end program maketau

!>>> spline green's function from old mesh to new mesh
  subroutine make_spline(ntime, norbs, beta, tau, grn)
     use constants

     implicit none

! local parameters
! predefined mesh size
     integer, parameter  :: ntau = 129

! external arguments
! number of imaginary time points
     integer, intent(in) :: ntime

! number of orbitals
     integer, intent(in) :: norbs

! inversion of temperature
     real(dp), intent(in) :: beta

! imaginary time mesh
     real(dp), intent(inout) :: tau(ntime)

! green's function data
     real(dp), intent(inout) :: grn(ntime,norbs)

! local variables
! loop index
     integer  :: i
     integer  :: j

! used to calculate 2nd derivates
     real(dp) :: startu, startd, deltau

! dummy imaginary time mesh
     real(dp) :: tau_t(ntau)

! dummy green's function data
     real(dp) :: grn_t(ntau,norbs)

! 2nd derivates of green's function
     real(dp) :: d2y(ntime)
     real(dp) :: g2d(ntime,norbs)

! external function, used to perform cubic spline interpolation
     real(dp) :: cat_make_splint

! calculate deltau
     deltau = beta / real( ntime - 1 )

! build new imaginary mesh
     do i=1,ntau
         tau_t(i) = beta * real( i - 1 ) / real( ntau - 1 )
     enddo ! over i={1,ntau} loop

! calculate 2nd derivates of green's function
     do i=1,norbs

! calculate first-order derivate of \Delta(0): startu
         startu = (-25.0_dp * grn(1,       i) +                    &
                    48.0_dp * grn(2,       i) -                    &
                    36.0_dp * grn(3,       i) +                    &
                    16.0_dp * grn(4,       i) -                    &
                     3.0_dp * grn(5,       i)) / 12.0_dp / deltau

! calculate first-order derivate of \Delta(\beta): startd
         startd = ( 25.0_dp * grn(ntime-0, i) -                    &
                    48.0_dp * grn(ntime-1, i) +                    &
                    36.0_dp * grn(ntime-2, i) -                    &
                    16.0_dp * grn(ntime-3, i) +                    &
                     3.0_dp * grn(ntime-4, i)) / 12.0_dp / deltau

! reinitialize d2y to zero
         d2y = zero

! call the service layer
         call cat_make_spline(ntime, tau, grn(:,i), startu, startd, d2y)

! copy the results to g2d
         g2d(:,i) = d2y

     enddo ! over i={1,norbs} loop

! perform cubic spline interpolation
     do i=1,norbs
         do j=1,ntau
             grn_t(j,i) = cat_make_splint(ntime, tau, grn(:,i), g2d(:,i), tau_t(j))
         enddo ! over j={1,ntau} loop
     enddo ! over i={1,norbs} loop

! overwrite the old imaginary time mesh
     do i=1,ntau
         tau(i) = tau_t(i)
     enddo ! over i={1,ntau} loop

! overwrite the old green's function data
     do i=1,norbs
         do j=1,ntau
             grn(j,i) = grn_t(j,i)
         enddo ! over j={1,ntau} loop
     enddo ! over i={1,norbs} loop

     return
  end subroutine make_spline

!>>> cat_make_spline: evaluate the 2-order derivates of yval
  subroutine cat_make_spline(ydim, xval, yval, startu, startd, d2y)
     use constants

     implicit none

! external arguments
! dimension of xval and yval
     integer, intent(in)   :: ydim

! first-derivate at point 1
     real(dp), intent(in)  :: startu

! first-derivate at point ydim
     real(dp), intent(in)  :: startd

! old knots
     real(dp), intent(in)  :: xval(ydim)

! old function values to be interpolated
     real(dp), intent(in)  :: yval(ydim)

! 2-order derivates
     real(dp), intent(out) :: d2y(ydim)

! local variables
! loop index
     integer  :: i
     integer  :: k

! dummy variables
     real(dp) :: p
     real(dp) :: qn
     real(dp) :: un
     real(dp) :: sig

! dummy arrays
     real(dp) :: u(ydim)

! deal with left boundary
     if ( startu > .99E30 ) then
         d2y(1) = zero
         u(1) = zero
     else
         p = xval(2) - xval(1)
         d2y(1) = -half
         u(1) = ( 3.0_dp / p ) * ( ( yval(2) - yval(1) ) / p - startu )
     endif

     do i=2,ydim-1
         sig    = ( xval(i) - xval(i-1) ) / ( xval(i+1) - xval(i-1) ) 
         p      = sig * d2y(i- 1) + two
         d2y(i) = ( sig - one ) / p 
         u(i)   = ( 6.0_dp * ( ( yval(i+1) - yval(i) ) / &
                    ( xval(i+1) - xval(i) ) - ( yval(i) - yval(i-1) ) / &
                    ( xval(i) - xval(i-1) ) ) / &
                    ( xval(i+1) - xval(i-1) ) - sig * u(i-1) ) / p
     enddo ! over i={2,ydim-1} loop

! deal with right boundary
     if ( startd > .99E30 ) then
         qn = zero
         un = zero
     else
         p = xval(ydim) - xval(ydim-1)
         qn = half
         un = ( 3.0_dp / p ) * ( startd - ( yval(ydim) - yval(ydim-1) ) / p )
     endif

     d2y(ydim) = ( un - qn * u(ydim-1) ) / ( qn * d2y(ydim-1) + one )

     do k=ydim-1,1,-1
         d2y(k) = d2y(k) * d2y(k+1) + u(k)
     enddo ! over k={ydim-1,1} loop

     return
  end subroutine cat_make_spline

!>>> cat_make_splint: evaluate the spline value at x point
  function cat_make_splint(xdim, xval, yval, d2y, x) result(val)
     use constants

     implicit none

! external arguments
! dimension of xval and yval
     integer, intent(in)  :: xdim

! new mesh point
     real(dp), intent(in) :: x

! old mesh
     real(dp), intent(in) :: xval(xdim)

! old function value
     real(dp), intent(in) :: yval(xdim)

! 2-order derviates of old function
     real(dp), intent(in) :: d2y(xdim)

! local variables
! lower boundary
     integer  :: khi

! higher boundary
     integer  :: klo

! distance between two successive mesh points
     real(dp) :: h

! dummy variables
     real(dp) :: a, b

! return value
     real(dp) :: val

! calculate the interval of spline zone
     h = xval(2) - xval(1)
 
! special trick is adopted to determine klo and kho
     val = x
     if ( val == xval(xdim) ) val = val - 0.00000001_dp
     klo = floor(val/h) + 1
     khi = klo + 1

! note: we do not need to check khi here, since x can not reach right boundary
! and left boundary either all
!<     if ( khi > xdim ) then
!<         klo = xdim - 1
!<         khi = xdim
!<     endif

! calculate splined parameters a and b
     a = ( xval(khi) - x ) / h
     b = ( x - xval(klo) ) / h

! spline it, obtain the fitted function value at x point
     val = a * yval(klo) + b * yval(khi) + &
               ( ( a*a*a - a ) * d2y(klo) + ( b*b*b - b ) * d2y(khi) ) * &
               ( h*h ) / 6.0_dp

     return
  end function cat_make_splint

!>>> smooth orginal green's function using bezier curves
  subroutine make_bezier(ntime, norbs, tau, grn)
     use constants

     implicit none

! external arguments
! number of imaginary time points
     integer, intent(in) :: ntime

! number of orbitals
     integer, intent(in) :: norbs

! imaginary time mesh
     real(dp), intent(inout) :: tau(ntime)

! green's function data
     real(dp), intent(inout) :: grn(ntime,norbs)

! local variables
! loop index
     integer  :: i, j, m

! intervals
     real(dp) :: dt, t

! current tau(i) and grn(i)
     real(dp) :: x, y

! dummy copy for tau and grn
     real(dp) :: tau_(ntime)
     real(dp) :: grn_(ntime)

! to store Bernstein polynomials
     real(dp) :: bern(ntime)

     dt = one / real(ntime - 1)

     do m=1,norbs
         do j=1,ntime
             t = dt * real(j - 1)

             x = zero
             y = zero

! to evaluate Bernstein polynomials
             call cat_make_bezier(ntime-1, t, bern)
             do i=1,ntime
                 y = y + grn(i,m) * bern(i)
             enddo ! over i={1,ntime} loop

! to evaluate Bernstein polynomials
             call cat_make_bezier(ntime-1, t, bern)
             do i=1,ntime
                 x = x + tau(i)   * bern(i)
             enddo ! over i={1,ntime} loop

             tau_(j) = x ! save x and y to tau_ and grn_ respectively
             grn_(j) = y
         enddo ! over m={1,ntime} loop
         grn(:,m) = grn_
     enddo ! over j={1,norbs} loop
     tau = tau_

     return
  end subroutine make_bezier

!>>> to evaluates the bernstein polynomials at a point x
! the bernstein polynomials are assumed to be based on [0,1].
! the formula is:
!    B(N,I)(X) = [N!/(I!*(N-I)!)] * (1-X)**(N-I) * X**I
! first values:
!    B(0,0)(X) = 1
!    B(1,0)(X) =      1-X
!    B(1,1)(X) =                X
!    B(2,0)(X) =     (1-X)**2
!    B(2,1)(X) = 2 * (1-X)    * X
!    B(2,2)(X) =                X**2
!    B(3,0)(X) =     (1-X)**3
!    B(3,1)(X) = 3 * (1-X)**2 * X
!    B(3,2)(X) = 3 * (1-X)    * X**2
!    B(3,3)(X) =                X**3
!    B(4,0)(X) =     (1-X)**4
!    B(4,1)(X) = 4 * (1-X)**3 * X
!    B(4,2)(X) = 6 * (1-X)**2 * X**2
!    B(4,3)(X) = 4 * (1-X)    * X**3
!    B(4,4)(X) =                X**4
! special values:
!    B(N,I)(X) has a unique maximum value at X = I/N.
!    B(N,I)(X) has an I-fold zero at 0 and and N-I fold zero at 1.
!    B(N,I)(1/2) = C(N,K) / 2**N
!    for a fixed X and N, the polynomials add up to 1:
!    sum ( 0 <= I <= N ) B(N,I)(X) = 1
  subroutine cat_make_bezier(n, x, bern)
     use constants

     implicit none

! external arguments
! the degree of the Bernstein polynomials to be used.  for any N, there
! is a set of N+1 Bernstein polynomials, each of degree N, which form a
! basis for polynomials on [0,1].
     integer, intent(in)  :: n

! the evaluation point.
     real(dp), intent(in) :: x

! the values of the N+1 Bernstein polynomials at X
     real(dp), intent(inout) :: bern(0:n)

! local variables
! loop index
     integer :: i
     integer :: j

     if ( n == 0 ) then
         bern(0) = one

     else if ( 0 < n ) then
         bern(0) = one - x
         bern(1) = x
         do i=2,n
             bern(i) = x * bern(i-1)
             do j=i-1,1,-1
                 bern(j) = x * bern(j-1) + ( one - x ) * bern(j)
             enddo ! over j={i-1,1} loop
             bern(0) = ( one - x ) * bern(0)
         enddo ! over i={2,n} loop

     endif ! back if ( n == 0 ) block
 
     return
  end subroutine cat_make_bezier
