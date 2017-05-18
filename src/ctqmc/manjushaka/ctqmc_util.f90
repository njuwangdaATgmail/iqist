!!!-----------------------------------------------------------------------
!!! project : manjushaka
!!! program : ctqmc_four_htau
!!!           ctqmc_four_hybf <<<---
!!!           ctqmc_eval_htau
!!!           ctqmc_eval_hsed <<<---
!!!           ctqmc_symm_nimp
!!!           ctqmc_symm_gtau
!!!           ctqmc_symm_grnf <<<---
!!!           ctqmc_make_gtau
!!!           ctqmc_make_ftau <<<---
!!!           ctqmc_make_prod <<<---
!!!           ctqmc_make_hub2 <<<---
!!! source  : ctqmc_util.f90
!!! type    : functions & subroutines
!!! author  : li huang (email:lihuang.dmft@gmail.com)
!!! history : 10/01/2008 by li huang (created)
!!!           05/18/2017 by li huang (last modified)
!!! purpose : provide utility functions and subroutines for hybridization
!!!           expansion version continuous time quantum Monte Carlo (CTQMC)
!!!           quantum impurity solver.
!!! status  : unstable
!!! comment :
!!!-----------------------------------------------------------------------

!!========================================================================
!!>>> fast fourier transformation                                      <<<
!!========================================================================

!!
!! note:
!!
!! here are forward and backward fourier transformation subroutines for
!! hybridization function. nominally, the following subroutines are only
!! suitable for the hybridization functions, but in principle, we can also
!! apply them to the impurity green's function and bath weiss's function
!!

!!
!! @sub ctqmc_four_htau
!!
!! fourier htau to hybf, from imaginary time to matsubara frequency
!!
  subroutine ctqmc_four_htau(htau, hybf)
     use constants, only : dp, zero, czero

     use control, only : norbs
     use control, only : mfreq
     use control, only : ntime

     use context, only : tmesh, rmesh

     implicit none

! external arguments
! hybridization function on imaginary time axis
     real(dp), intent(in) :: htau(ntime,norbs,norbs)

! hybridization function on matsubara frequency axis
     complex(dp), intent(out) :: hybf(mfreq,norbs,norbs)

! local variables
! loop index over orbitals
     integer  :: i
     integer  :: j

! dummy arrays
     real(dp) :: raux(ntime)
     complex(dp) :: caux(mfreq)

! initialize them
     raux = zero
     caux = czero

     do i=1,norbs
         do j=1,norbs

! copy the imaginary time data to raux
             raux = htau(:,j,i)

! call the service layer
             call s_fft_forward(ntime, tmesh, raux, mfreq, rmesh, caux)

! copy the matsubara frequency data to hybf
             hybf(:,j,i) = caux

         enddo ! over j={1,norbs} loop
     enddo ! over i={1,norbs} loop

     return
  end subroutine ctqmc_four_htau

!!
!! @sub ctqmc_four_hybf
!!
!! fourier hybf to htau, from matsubara frequency to imaginary time
!!
  subroutine ctqmc_four_hybf(hybf, htau)
     use constants, only : dp, zero, czero, eps6

     use control, only : norbs
     use control, only : mfreq
     use control, only : ntime
     use control, only : beta

     use context, only : tmesh, rmesh

     implicit none

! external arguments
! hybridization function on imaginary time axis
     real(dp), intent(out) :: htau(ntime,norbs,norbs)

! hybridization function on matsubara frequency axis
     complex(dp), intent(in) :: hybf(mfreq,norbs,norbs)

! local variables
! loop index over orbitals
     integer  :: i
     integer  :: j

! used to determine the bottom region of hybridiaztion function
     integer  :: start
     integer  :: last

! dummy arrays
     real(dp) :: raux(ntime)
     complex(dp) :: caux(mfreq)

! initialize them
     raux = zero
     caux = czero

     do i=1,norbs
         do j=1,norbs

! copy matsubara frequency data to caux
             caux = hybf(:,j,i)

! call the service layer
             call s_fft_backward(mfreq, rmesh, caux, ntime, tmesh, raux, beta)

! copy imaginary time data to htau
             htau(:,j,i) = raux

         enddo ! over j={1,norbs} loop
     enddo ! over i={1,norbs} loop

! checks for diagonal htau to be causal. htau should be concave. hence,
! if it becomes very small at two points, it should remain zero in all
! points between the two points. this is very important in insulators,
! because htau can overshoot to positive values multiple times and kinks
! can be trapped in the range between the two crossing points, where htau
! is causal, but should be zero.
     start = 1
     last = 1
     do i=1,norbs
         do j=1,ntime    ! search forward
             if ( htau(j,i,i) > -eps6 ) then
                 start = j; EXIT
             endif ! back if ( htau(j,i,i) > -eps6 ) block
         enddo ! over j={1,ntime} loop

         do j=ntime,1,-1 ! search backward
             if ( htau(j,i,i) > -eps6 ) then
                 last = j; EXIT
             endif ! back if ( htau(j,i,i) > -eps6 ) block
         enddo ! over j={ntime,1,-1} loop

!-------------------------------------------------------------------------
!<         if ( start > 1 .and. last > 1 ) then
!<             do j=start,last
!<                 htau(j,i,i) = -eps6
!<             enddo ! over j={start,last} loop
!<         endif ! back if ( start > 1 .and. last > 1 ) block
!-------------------------------------------------------------------------
     enddo ! over i={1,norbs} loop

! enforce hybridization function less than zero to ensure the causality
     do i=1,norbs
         do j=1,ntime
             if ( htau(j,i,i) > zero ) htau(j,i,i) = -eps6
         enddo ! over j={1,ntime} loop
     enddo ! over i={1,norbs} loop

     return
  end subroutine ctqmc_four_hybf

!!========================================================================
!!>>> cubic spline interpolation                                       <<<
!!========================================================================

!!
!! note:
!!
!! to provide cubic spline subroutine and wrapper function to interpolate
!! the hybridization function in imaginary time axis
!!

!!
!! @fun ctqmc_eval_htau
!!
!! evaluate the matrix elements for mmat matrix using cubic spline
!! interpolation method
!!
  function ctqmc_eval_htau(flvr, dtau) result(val)
     use constants, only : dp

     use control, only : ntime

     use context, only : tmesh
     use context, only : htau, hsed

     implicit none

! external arguments
! current flavor channel
     integer, intent(in)  :: flvr

! delta imaginary time
     real(dp), intent(in) :: dtau

! external functions
! internal interpolation engine
     procedure( real(dp) ) :: s_spl_funct

! local variables
! return value
     real(dp) :: val

     val = s_spl_funct(ntime, tmesh, htau(:, flvr, flvr), hsed(:, flvr, flvr), dtau)

     return
  end function ctqmc_eval_htau

!!
!! @sub ctqmc_eval_hsed
!!
!! calculate the second order derivates of hybridization function on
!! imaginary time space
!!
  subroutine ctqmc_eval_hsed(htau, hsed)
     use constants, only : dp, zero

     use control, only : norbs
     use control, only : ntime
     use control, only : beta

     use context, only : tmesh

     implicit none

! external arguments
! hybridization function on imaginary time axis
     real(dp), intent(in)  :: htau(ntime,norbs,norbs)

! second order derivates of hybridization function
     real(dp), intent(out) :: hsed(ntime,norbs,norbs)

! local variables
! loop index
     integer  :: i
     integer  :: j

! first derivate at start point
     real(dp) :: startu

! first derivate at end   point
     real(dp) :: startd

! \delta \tau
     real(dp) :: deltau

! second-order derivates
     real(dp) :: d2y(ntime)

! calculate deltau
     deltau = beta / real(ntime - 1)

! initialize hsed
     hsed = zero

! calculate it
     do j=1,norbs
         do i=1,norbs

! calculate first-order derivate of \Delta(0): startu
             startu = (-25.0_dp*htau(1,       i, j) +                    &
                        48.0_dp*htau(2,       i, j) -                    &
                        36.0_dp*htau(3,       i, j) +                    &
                        16.0_dp*htau(4,       i, j) -                    &
                         3.0_dp*htau(5,       i, j)) / 12.0_dp / deltau

! calculate first-order derivate of \Delta(\beta): startd
             startd = ( 25.0_dp*htau(ntime-0, i, j) -                    &
                        48.0_dp*htau(ntime-1, i, j) +                    &
                        36.0_dp*htau(ntime-2, i, j) -                    &
                        16.0_dp*htau(ntime-3, i, j) +                    &
                         3.0_dp*htau(ntime-4, i, j)) / 12.0_dp / deltau

! reinitialize d2y to zero
             d2y = zero

! call the service layer
             call s_spl_deriv2(ntime, tmesh, htau(:,i,j), startu, startd, d2y)

! copy the results to hsed
             hsed(:,i,j) = d2y

         enddo ! over i={1,norbs} loop
     enddo ! over j={1,norbs} loop

     return
  end subroutine ctqmc_eval_hsed

!!========================================================================
!!>>> symmetrize operation                                             <<<
!!========================================================================

!!
!! @sub ctqmc_symm_nimp
!!
!! symmetrize the occupation number array, nimp, according to symm vector
!!
  subroutine ctqmc_symm_nimp(symm, nimp)
     use constants, only : dp, zero, two

     use control, only : isbnd, isspn
     use control, only : nband, norbs

     implicit none

! external arguments
! symmetry vector
     integer, intent(in) :: symm(norbs)

! occupation number
     real(dp), intent(inout) :: nimp(norbs)

! local variables
! loop index over bands
     integer  :: ibnd
     integer  :: jbnd

! dummy variables
     real(dp) :: raux

! histogram vector
! note: it is NOT the global one
     integer  :: hist(norbs)

! build histogram
     hist = 0
     do ibnd=1,norbs
         hist(symm(ibnd)) = hist(symm(ibnd)) + 1
     enddo ! over ibnd={1,norbs} loop

! perform symmetrization for those orbitals with the same symmetry
     if ( isbnd == 2 ) then
         do ibnd=1,norbs
             if ( hist(ibnd) > 0 ) then         ! need to enforce symmetry
                 raux = zero

                 do jbnd=1,norbs                ! gather the data
                     if ( symm(jbnd) == ibnd ) then
                         raux = raux + nimp(jbnd)
                     endif ! back if ( symm(jbnd) == ibnd ) block
                 enddo ! over jbnd={1,norbs} loop

                 raux = raux / real(hist(ibnd)) ! calculate average value

                 do jbnd=1,norbs                ! setup it
                     if ( symm(jbnd) == ibnd ) then
                         nimp(jbnd) = raux
                     endif ! back if ( symm(jbnd) == ibnd ) block
                 enddo ! over jbnd={1,norbs} loop
             endif ! back if ( hist(ibnd) > 0 ) block
         enddo ! over ibnd={1,norbs} loop
     endif ! back if ( isbnd == 2 ) block

! symmetrize nimp over spin
     if ( isspn == 2 ) then
         do jbnd=1,nband
             raux = ( nimp(jbnd) + nimp(jbnd+nband) ) / two
             nimp(jbnd) = raux
             nimp(jbnd+nband) = raux
         enddo ! over jbnd={1,nband} loop
     endif ! back if ( isspn == 2 ) block

     return
  end subroutine ctqmc_symm_nimp

!!
!! @sub ctqmc_symm_gtau
!!
!! symmetrize the gtau according to symm vector. only the diagonal
!! elements are taken into considerations
!!
  subroutine ctqmc_symm_gtau(symm, gtau)
     use constants, only : dp, zero, two

     use control, only : isbnd, isspn
     use control, only : nband, norbs
     use control, only : ntime

     implicit none

! external arguments
! symmetry vector
     integer, intent(in) :: symm(norbs)

! impurity green's function
     real(dp), intent(inout) :: gtau(ntime,norbs,norbs)

! local variables
! loop index over bands
     integer  :: ibnd
     integer  :: jbnd

! loop index over imaginary time points
     integer  :: ktau

! dummy variables
     real(dp) :: raux

! histogram vector
! note: it is NOT the global one
     integer  :: hist(norbs)

! build histogram
     hist = 0
     do ibnd=1,norbs
         hist(symm(ibnd)) = hist(symm(ibnd)) + 1
     enddo ! over ibnd={1,norbs} loop

! perform symmetrization for those orbitals with the same symmetry
     if ( isbnd == 2 ) then
         do ktau=1,ntime
             do ibnd=1,norbs
                 if ( hist(ibnd) > 0 ) then         ! need to enforce symmetry
                     raux = zero

                     do jbnd=1,norbs                ! gather the data
                         if ( symm(jbnd) == ibnd ) then
                             raux = raux + gtau(ktau,jbnd,jbnd)
                         endif ! back if ( symm(jbnd) == ibnd ) block
                     enddo ! over jbnd={1,norbs} loop

                     raux = raux / real(hist(ibnd)) ! calculate average value

                     do jbnd=1,norbs                ! setup it
                         if ( symm(jbnd) == ibnd ) then
                             gtau(ktau,jbnd,jbnd) = raux
                         endif ! back if ( symm(jbnd) == ibnd ) block
                     enddo ! over jbnd={1,norbs} loop
                 endif ! back if ( hist(ibnd) > 0 ) block
             enddo ! over ibnd={1,norbs} loop
         enddo ! over ktau={1,ntime} loop
     endif ! back if ( isbnd == 2 ) block

! symmetrize gtau over spin
     if ( isspn == 2 ) then
         do ktau=1,ntime
             do jbnd=1,nband
                 raux = ( gtau(ktau,jbnd,jbnd) + gtau(ktau,jbnd+nband,jbnd+nband) ) / two
                 gtau(ktau,jbnd,jbnd) = raux
                 gtau(ktau,jbnd+nband,jbnd+nband) = raux
             enddo ! over jbnd={1,nband} loop
         enddo ! over ktau={1,ntime} loop
     endif ! back if ( isspn == 2 ) block

     return
  end subroutine ctqmc_symm_gtau

!!
!! @sub ctqmc_symm_grnf
!!
!! symmetrize the grnf according to symm vector. only the diagonal
!! elements are taken into considerations
!!
  subroutine ctqmc_symm_grnf(symm, grnf)
     use constants, only : dp, two, czero

     use control, only : isbnd, isspn
     use control, only : nband, norbs
     use control, only : mfreq

     implicit none

! external arguments
! symmetry vector
     integer, intent(in) :: symm(norbs)

! impurity green's function
     complex(dp), intent(inout) :: grnf(mfreq,norbs,norbs)

! local variables
! loop index over bands
     integer :: ibnd
     integer :: jbnd

! loop index over matsubara frequencies
     integer :: kfrq

! dummy variables
     complex(dp) :: caux

! histogram vector
! note: it is NOT the global one
     integer :: hist(norbs)

! build histogram
     hist = 0
     do ibnd=1,norbs
         hist(symm(ibnd)) = hist(symm(ibnd)) + 1
     enddo ! over ibnd={1,norbs} loop

! perform symmetrization for those orbitals with the same symmetry
     if ( isbnd == 2 ) then
         do kfrq=1,mfreq
             do ibnd=1,norbs
                 if ( hist(ibnd) > 0 ) then         ! need to enforce symmetry
                     caux = czero

                     do jbnd=1,norbs                ! gather the data
                         if ( symm(jbnd) == ibnd ) then
                             caux = caux + grnf(kfrq,jbnd,jbnd)
                         endif ! back if ( symm(jbnd) == ibnd ) block
                     enddo ! over jbnd={1,norbs} loop

                     caux = caux / real(hist(ibnd)) ! calculate average value

                     do jbnd=1,norbs                ! setup it
                         if ( symm(jbnd) == ibnd ) then
                             grnf(kfrq,jbnd,jbnd) = caux
                         endif ! back if ( symm(jbnd) == ibnd ) block
                     enddo ! over jbnd={1,norbs} loop
                 endif ! back if ( hist(ibnd) > 0 ) block
             enddo ! over ibnd={1,norbs} loop
         enddo ! over kfrq={1,mfreq} loop
     endif ! back if ( isbnd == 2 ) block

! symmetrize grnf over spin
     if ( isspn == 2 ) then
         do kfrq=1,mfreq
             do jbnd=1,nband
                 caux = ( grnf(kfrq,jbnd,jbnd) + grnf(kfrq,jbnd+nband,jbnd+nband) ) / two
                 grnf(kfrq,jbnd,jbnd) = caux
                 grnf(kfrq,jbnd+nband,jbnd+nband) = caux
             enddo ! over jbnd={1,nband} loop
         enddo ! over kfrq={1,mfreq} loop
     endif ! back if ( isspn == 2 ) block

     return
  end subroutine ctqmc_symm_grnf

!!========================================================================
!!>>> advanced representation                                          <<<
!!========================================================================

!!
!! @sub ctqmc_make_gtau
!!
!! build imaginary time green's function using different representation
!!
  subroutine ctqmc_make_gtau(tmesh, gtau, gaux)
     use constants, only : dp, zero, one, two, pi

     use control, only : isort
     use control, only : norbs
     use control, only : lemax, legrd, chmax, chgrd
     use control, only : ntime
     use control, only : beta
     use context, only : ppleg, qqche

     implicit none

! external arguments
! imaginary time mesh
     real(dp), intent(in)  :: tmesh(ntime)

! impurity green's function/orthogonal polynomial coefficients
     real(dp), intent(in)  :: gtau(ntime,norbs,norbs)

! calculated impurity green's function
     real(dp), intent(out) :: gaux(ntime,norbs,norbs)

! local parameters
! scheme of integral kernel used to damp the Gibbs oscillation
! damp = 0, Dirichlet   mode
! damp = 1, Jackson     mode, preferred
! damp = 2, Lorentz     mode
! damp = 3, Fejer       mode
! damp = 4, Wang-Zunger mode
     integer, parameter :: damp = 0

! local variables
! loop index
     integer  :: i
     integer  :: j

! loop index for legendre polynomial
     integer  :: fleg

! loop index for chebyshev polynomial
     integer  :: fche

! index for imaginary time \tau
     integer  :: curr

! interval for imaginary time slice
     real(dp) :: step

! dummy variables
     real(dp) :: raux

! initialize gaux
     gaux = zero

! select calculation method
     select case ( isort )

         case (1, 4)
             call cat_make_gtau1()

         case (2, 5)
             call cat_make_gtau2()

         case (3, 6)
             call cat_make_gtau3()

     end select

     return

  contains

!!>>> cat_make_kpm: build the integral kernel function
  subroutine cat_make_kpm(kdim, kern)
     implicit none

! external arguments
! dimension of integral kernel function
     integer, intent(in)   :: kdim

! integral kernel function
     real(dp), intent(out) :: kern(kdim)

! local variables
! loop index
     integer :: kcur

     kern = zero
     do kcur=1,kdim
         select case ( damp )

! Dirichlet mode
             case (0)
                 kern(kcur) = one

! Jackson mode
             case (1)
                 i = kcur - 1
                 curr = kdim + 1
                 raux = pi * i / curr
                 kern(kcur) = ( (curr-i) * cos(raux) + sin(raux) / tan(pi/curr) ) / curr

! Lorentz mode
             case (2)
                 kern(kcur) = sinh( one - (kcur - one) / real( kdim ) ) / sinh(one)

! Fejer mode
             case (3)
                 kern(kcur) = one - ( kcur - one ) / real( kdim )

! Wang-Zunger mode
             case (4)
                 kern(kcur) = exp( - ( (kcur - one) / real( kdim ) )**4 )

         end select
     enddo ! over kcur={1,kdim} loop

     return
  end subroutine cat_make_kpm

!!>>> cat_make_gtau1: build impurity green's function using normal
!!>>> representation
  subroutine cat_make_gtau1()
     implicit none

     raux = real(ntime) / (beta * beta)
     do i=1,norbs
         do j=1,ntime
             gaux(j,i,i) = gtau(j,i,i) * raux
         enddo ! over j={1,ntime} loop
     enddo ! over i={1,norbs} loop

     return
  end subroutine cat_make_gtau1

!!>>> cat_make_gtau2: build impurity green's function using legendre
!!>>> polynomial representation
  subroutine cat_make_gtau2()
     implicit none

! integral kernel
     real(dp) :: ker1(lemax)

! build kernel function at first
     ker1 = one; call cat_make_kpm(lemax, ker1)

! reconstruct green's function
     step = real(legrd - 1) / two
     do i=1,norbs
         do j=1,ntime
             raux = two * tmesh(j) / beta
             curr = nint(raux * step) + 1
             do fleg=1,lemax
                 raux = sqrt(two * fleg - 1) / (beta * beta) * ker1(fleg)
                 gaux(j,i,i) = gaux(j,i,i) + raux * gtau(fleg,i,i) * ppleg(curr,fleg)
             enddo ! over fleg={1,lemax} loop
         enddo ! over j={1,ntime} loop
     enddo ! over i={1,norbs} loop

     return
  end subroutine cat_make_gtau2

!!>>> cat_make_gtau3: build impurity green's function using chebyshev
!!>>> polynomial representation
  subroutine cat_make_gtau3()
     implicit none

! integral kernel
     real(dp) :: ker2(chmax)

! build kernel function at first
     ker2 = one; call cat_make_kpm(chmax, ker2)

! reconstruct green's function
     step = real(chgrd - 1) / two
     do i=1,norbs
         do j=1,ntime
             raux = two * tmesh(j) / beta
             curr = nint(raux * step) + 1
             do fche=1,chmax
                 raux = two / (beta * beta) * ker2(fche)
                 gaux(j,i,i) = gaux(j,i,i) + raux * gtau(fche,i,i) * qqche(curr,fche)
             enddo ! over fche={1,chmax} loop
         enddo ! over j={1,ntime} loop
     enddo ! over i={1,norbs} loop

     return
  end subroutine cat_make_gtau3
  end subroutine ctqmc_make_gtau

!!========================================================================
!!>>> build auxiliary two-particle related variables                   <<<
!!========================================================================

!!>>> ctqmc_make_prod: try to calculate the product of matsubara
!!>>> frequency exponents exp(i \omega_n \tau)
  subroutine ctqmc_make_prod(flvr, nfaux, mrank, caux1, caux2)
     use constants, only : dp, two, pi, czi

     use control, only : nffrq
     use control, only : beta
     use context, only : index_s, index_e, time_s, time_e
     use context, only : rank

     implicit none

! external arguments
! current flavor channel
     integer, intent(in) :: flvr

! combination of nffrq and nbfrq
     integer, intent(in) :: nfaux

! maximum number of operators in different flavor channels
     integer, intent(in) :: mrank

! matsubara frequency exponents for create operators
     complex(dp), intent(out) :: caux1(nfaux,mrank)

! matsubara frequency exponents for destroy operators
     complex(dp), intent(out) :: caux2(nfaux,mrank)

! local variables
! loop indices for start and end points
     integer  :: is
     integer  :: ie

! imaginary time for start and end points
     real(dp) :: taus
     real(dp) :: taue

! for create operators
     do is=1,rank(flvr)
         taus = time_s( index_s(is, flvr), flvr )
         caux1(:,is) = exp(-two * czi * pi * taus / beta)
         call s_cumprod_z(nfaux, caux1(:,is), caux1(:,is))
         caux1(:,is) = caux1(:,is) * exp(+(nffrq + 1) * czi * pi * taus / beta)
     enddo ! over is={1,rank(flvr)} loop

! for destroy operators
     do ie=1,rank(flvr)
         taue = time_e( index_e(ie, flvr), flvr )
         caux2(:,ie) = exp(+two * czi * pi * taue / beta)
         call s_cumprod_z(nfaux, caux2(:,ie), caux2(:,ie))
         caux2(:,ie) = caux2(:,ie) * exp(-(nffrq + 1) * czi * pi * taue / beta)
     enddo ! over ie={1,rank(flvr)} loop

     return
  end subroutine ctqmc_make_prod

!!========================================================================
!!>>> build self-energy function                                       <<<
!!========================================================================

!!>>> ctqmc_make_hub1: build atomic green's function and self-energy
!!>>> function using improved Hubbard-I approximation, and then make
!!>>> interpolation for self-energy function between low frequency QMC
!!>>> data and high frequency Hubbard-I approximation data, the full
!!>>> impurity green's function can be obtained by using dyson's equation
!!>>> finally
  subroutine ctqmc_make_hub1()
     use constants, only : dp, zero, one, czi, czero

     use control, only : norbs
     use control, only : mfreq
     use control, only : nfreq
     use control, only : mune
     use control, only : myid, master
     use context, only : rmesh
     use context, only : prob
     use context, only : eimp, eigs
     use context, only : grnf
     use context, only : hybf
     use context, only : sig2

     use m_sect, only : nsect
     use m_sect, only : sectors
     use m_sect, only : sectoff

     implicit none

! local variables
! loop index
     integer  :: i
     integer  :: j
     integer  :: k
     integer  :: l
     integer  :: m
     integer  :: n

! start index of sectors
     integer  :: indx1
     integer  :: indx2

! dummy integer variables
     integer  :: start

! dummy real variables, used to interpolate self-energy function
     real(dp) :: ob, oe
     real(dp) :: d0, d1

! dummy complex variables, used to interpolate self-energy function
     complex(dp) :: cb, ce
     complex(dp) :: sinf

! dummy imurity green's function: G^{-1}
     complex(dp) :: gaux(norbs,norbs)

! atomic green's function and self-energy function in Hubbard-I approximation
     complex(dp) :: ghub(mfreq,norbs)
     complex(dp) :: shub(mfreq,norbs)

! calculate atomic green's function using Hubbard-I approximation
     ghub = czero
     do i=1,norbs
         do j=1,nsect
             l = sectors(j)%next(i,0)
             if ( l == -1 ) CYCLE
             if ( sectoff(j) .eqv. .true. .or. sectoff(l) .eqv. .true. ) CYCLE
             indx1 = sectors(j)%istart
             indx2 = sectors(l)%istart
             do n=1,sectors(j)%ndim
                 do m=1,sectors(l)%ndim
                     ob = sectors(j)%fmat(i,0)%val(m,n) ** 2 * (prob(indx2+m-1) + prob(indx1+n-1))
                     do k=1,mfreq
                         cb = czi * rmesh(k) + eigs(indx2+m-1) - eigs(indx1+n-1)
                         ghub(k,i) = ghub(k,i) + ob / cb
                     enddo ! over k={1,mfreq} loop
                 enddo ! over m={1,sectors(l)%ndim} loop
             enddo ! over n={1,sectors(j)%ndim} loop
         enddo ! over j={1,nsect} loop
     enddo ! over i={1,norbs} loop

! calculate atomic self-energy function using dyson's equation
     do i=1,norbs
         do k=1,mfreq
             shub(k,i) = czi * rmesh(k) + mune - eimp(i) - one / ghub(k,i)
         enddo ! over k={1,mfreq} loop
     enddo ! over i={1,norbs} loop

! dump the ghub and shub, only for reference, only the master node can do it
     if ( myid == master ) then
         call ctqmc_dump_hub1(rmesh, ghub, shub)
     endif ! back if ( myid == master ) block

! build self-energy function at low frequency region
!-------------------------------------------------------------------------
! filter grnf to suppress the fluctuation of its real part
!-------------------------------------------------------------------------
!<     do k=1,nfreq
!<         do i=1,norbs
!<             ob =  real( grnf(k,i,i) )
!<             oe = aimag( grnf(k,i,i) )
!<             grnf(k,i,i) = dcmplx( zero, oe )
!<         enddo ! over i={1,norbs} loop
!<     enddo ! over k={1,nfreq} loop
!^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
     do k=1,nfreq
         gaux = grnf(k,:,:)
         call s_inv_z(norbs, gaux)
         do i=1,norbs
             sig2(k,i,i) = czi * rmesh(k) + mune - eimp(i) - gaux(i,i) - hybf(k,i,i)
         enddo ! over i={1,norbs} loop
     enddo ! over k={1,nfreq} loop
!-------------------------------------------------------------------------
! filter sig2 to suppress the fluctuation of its imaginary part
!-------------------------------------------------------------------------
     do k=1,16
         do i=1,norbs
             call ctqmc_smth_sigf( sig2(1:nfreq,i,i) ) ! smooth it 16 times
         enddo ! over i={1,norbs} loop
     enddo ! over k={1,16} loop
!^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

! interpolates self-energy function between low energy QMC data and high
! energy Hubbard-I approximation
     do i=1,norbs

! determine the base point, its value is calculated by using five points
         cb = czero
         do k=nfreq-4,nfreq
             cb = cb + sig2(k,i,i)
         enddo ! over k={nfreq-4,nfreq} loop

         cb = cb / real(5)
         ob = rmesh(nfreq-2)

! step A: for the imaginary part
! determine the intermediate region [nfreq+1,start] at first
         start = 0
         do k=nfreq+1,mfreq
             start = k
             d0 = aimag( shub(k,i) - cb ) / ( rmesh(k) - ob )
             d1 = aimag( shub(k,i) - shub(k-1,i) ) / ( rmesh(k) - rmesh(k-1) )
             if ( abs( d0 - d1 ) < 0.02_dp ) EXIT
         enddo ! over k={nfreq+1,mfreq} loop

! we just constrain start \in [nfreq + 32, nfreq + 128]
         if ( start - nfreq <  32 ) start = nfreq +  32
         if ( start - nfreq > 128 ) start = nfreq + 128

         ce = shub(start,i)
         oe = rmesh(start)

! deal with the intermediate region, using linear interpolation
         do k=nfreq+1,start
             sig2(k,i,i) = dcmplx( zero, aimag(cb) + aimag( ce - cb ) * ( rmesh(k) - ob ) / ( oe - ob ) )
         enddo ! over k={nfreq+1,start} loop

! deal with the tail region, using atomic self-energy function directly
         do k=start+1,mfreq
             sig2(k,i,i) = dcmplx( zero, aimag( shub(k,i) ) )
         enddo ! over k={start+1,mfreq} loop

! step B: for the real part
         sinf = shub(mfreq,i)
         do k=nfreq+1,mfreq
             sig2(k,i,i) = sig2(k,i,i) + real(sinf) + ( ob / rmesh(k) )**2 * real( cb - sinf )
         enddo ! over k={nfreq+1,mfreq} loop

     enddo ! over i={1,norbs} loop

! calculate final impurity green's function using dyson's equation
     do k=1,mfreq
         gaux = czero
         do i=1,norbs
             gaux(i,i) = czi * rmesh(k) + mune - eimp(i) - sig2(k,i,i) - hybf(k,i,i)
         enddo ! over i={1,norbs} loop
         call s_inv_z(norbs, gaux)
         grnf(k,:,:) = gaux
     enddo ! over k={1,mfreq} loop

     return
  end subroutine ctqmc_make_hub1
