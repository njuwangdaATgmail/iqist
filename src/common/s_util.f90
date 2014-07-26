!!!-----------------------------------------------------------------------
!!! project : CSSL (Common Service Subroutines Library)
!!! program : s_assert
!!!           s_sorter
!!!           s_qsorter
!!!           s_qscorer
!!!           s_str_upcase
!!!           s_str_lowcase
!!!           s_str_count
!!!           s_str_compress
!!!           s_time_builder
!!!           s_time_analyzer
!!! source  : s_util.f90
!!! type    : subroutines
!!! author  : li huang (email:huangli712@gmail.com)
!!! history : 07/10/2014 by li huang
!!!           07/14/2014 by li huang
!!!           07/26/2014 by li huang
!!! purpose : these subroutines are used to provide some useful facilities
!!!           including string manipulation, date time information, etc.
!!! status  : unstable
!!! comment :
!!!-----------------------------------------------------------------------

!!========================================================================
!!>>> assertion checker                                                <<<
!!========================================================================

!!>>> s_assert: fortran version of assert
  subroutine s_assert(condition)
     implicit none

! external arguments
     logical, intent(in) :: condition

! if condition == .false., it aborts the program.
     if ( .not. condition ) then
         call s_print_error("s_assert", "assert failed.")
     endif

     return
  end subroutine s_assert

!!========================================================================
!!>>> sort algorithm                                                   <<<
!!========================================================================

!!>>> s_sorter: using bubble sort algorithm to sort a real dataset, the slowest algorithm
  subroutine s_sorter(nsize, list)
     use constants, only : dp

     implicit none

! external arguments
! grab the number of values from the calling code
     integer, intent(in) :: nsize

! dataset to be sorted
     real(dp), intent(inout) :: list(nsize)

! local variables
! dataset index
     integer  :: i = 0
     integer  :: j = 0

! dummy variables
     real(dp) :: swap

! basically we just loop through every element to compare it against
! every other element
! this loop increments i which is our starting point for the comparison
     sort_loop1: do i=nsize,1,-1
! this loop increments j which is the ending point for the comparison
         sort_loop2: do j=1,i-1
! swap the two elements here
             exchange: if ( list(j) > list(j+1) ) then
                 swap = list(j)
                 list(j) = list(j+1)
                 list(j+1) = swap
             endif exchange
         enddo sort_loop2 ! over j={1,i-1} loop
     enddo sort_loop1 ! over i={nsize,1,-1} loop

     return
  end subroutine s_sorter

!!>>> s_qsorter: sets up for the quick sort recursive method
  subroutine s_qsorter(nsize, list)
     use constants, only : dp

     implicit none

! external arguments
! grab the number of values from the calling code
     integer, intent(in) :: nsize

! dataset to be sorted
     real(dp), intent(inout) :: list(nsize)

! kicks off the recursive process
     call s_qscorer(1, nsize, nsize, list)

     return
  end subroutine s_qsorter

!!>>> s_qscorer: this is the actually recursive portion of the quicksort algorithm
!!>>> note: do not call it directly, please use s_qsorter() insteadly
  recursive &
  subroutine s_qscorer(pstart, pend, nsize, list)
     use constants, only : dp

     implicit none

! external arguments
! start point
     integer, intent(in) :: pstart

! end point
     integer, intent(in) :: pend

! size of array
     integer, intent(in) :: nsize

! dataset to be sorted
     real(dp), intent(inout) :: list(nsize)

! local variables
! used to find out list(left) > kaux and list(right) < kaux
     integer  :: left, right

! used to record list(pstart)
     real(dp) :: kaux

! used to swap data
     real(dp) :: taux

! setup left and right
     left = pstart
     right = pend + 1

! only in right > left, the data is to be sorted
     if ( right > left ) then

! record list(pstart) at first
         kaux = list(pstart)

         do while ( .true. )

! find out where list(left) < kaux
             do while ( .true. )
                 left = left + 1
                 if ( list(left)  > kaux .or. left  >= pend   ) EXIT
             enddo ! over do while loop

! find out where list(right) > kaux
             do while ( .true. )
                 right = right - 1
                 if ( list(right) < kaux .or. right <= pstart ) EXIT
             enddo ! over do while loop

! we should ensure right is larger than left
             if ( right <= left ) EXIT

! exchange data between list(left) and list(right)
             taux = list(left)
             list(left) = list(right)
             list(right) = taux

         enddo ! over do while loop

! exchange data between list(pstart) and list(right)
        list(pstart) = list(right)
        list(right) = kaux

! sort data from pstart to right-1
        call s_qscorer(pstart, right-1, nsize, list)

! sort data from right+1 to pend
        call s_qscorer(right+1, pend, nsize, list)

     endif ! back if ( right > left ) block

     return
  end subroutine s_qscorer

!!========================================================================
!!>>> string manipulation                                              <<<
!!========================================================================

!!>>> s_str_upcase: returns string 's' in uppercase
  subroutine s_str_upcase(s)
     implicit none

! external arguments
! input/output string
     character(*), intent(inout) :: s

! local variables
! loop index
     integer :: i

! difference between 'A' and 'a'
     integer :: diff

     diff = ichar('A') - ichar('a')

! if lowercase, make uppercase
     do i=1,len(s)
         if ( ichar(s(i:i)) >= ichar('a') .and. ichar(s(i:i)) <= ichar('z') ) then
             s(i:i) = char(ichar(s(i:i)) + diff)
         endif ! back if block
     enddo ! over i={1,len(s)} loop

     return
  end subroutine s_str_upcase

!!>>> s_str_lowcase: returns string 's' in lowercase
  subroutine s_str_lowcase(s)
     implicit none

! external arguments
! input/output string
     character(*), intent(inout) :: s

! local variables
! loop index
     integer :: i

! difference between 'A' and 'a'
     integer :: diff

     diff = ichar('A') - ichar('a')

! if uppercase, make lowercase
     do i=1,len(s)
         if ( ichar(s(i:i)) >= ichar('A') .and. ichar(s(i:i)) <= ichar('Z') ) then
             s(i:i) = char(ichar(s(i:i)) - diff)
         endif ! back if block
     enddo ! over i={1,len(s)} loop

     return
  end subroutine s_str_lowcase

!!>>> s_str_count: return the number of times a substring occurs
  subroutine s_str_count(string, substr, count)
     implicit none

! external arguments
! string to be examined
     character(len=*), intent(in) :: string

! substring in question
     character(len=*), intent(in) :: substr

! return value, number of occurrences
     integer, intent(out) :: count

! local variables
! position to start the match
     integer :: start
     integer :: offset

     count = 0
     start = 0
     do
         offset = index( string(start+1:), substr )
         if ( offset == 0 ) EXIT
         start = start + offset
         count = count + 1
     enddo ! over do loop

     return
  end subroutine s_str_count

!!>>> s_str_compress: return a copy of an input string with all whitespace
!!>>> (spaces and tabs) removed.
  subroutine s_str_compress(string)
     implicit none

! external arguments
! character string to be compressed.
     character( * ), intent(inout) :: string

! local parameters
! ASCII number for tab space ' ' and tab 
     integer, parameter :: SPACE = 32
     integer, parameter :: TAB   = 9
     integer, parameter :: NUL   = 0

! local variables
! loop index
     integer :: i
     integer :: j

! ASCII number for current character
     integer :: curr_char

! return values
! input string with all whitespace removed before the first non-whitespace
! character, and from in-between non-whitespace characters.
     character( len( string ) ) :: output

!
! definitions of a space and a tab character are made for the ASCII collating
! sequence. Each single character of the input string is checked against
! these definitions using the IACHAR() intrinsic. If the input string
! character DOESNOT correspond to a space or tab, it is not copied to
! the output string.
!
! Note that for input that ONLY has spaces or tabs BEFORE the first useful
! character, the output of this function is the same as the ADJUSTL() instrinsic.
!

! Initialise output string
     output = ' '

! initialise output string "useful" length counter
     j = 0

! loop over string elements
     do i=1,len(string)
! convert the current character to its position in the ASCII collating sequence
         curr_char = iachar( string(i:i) )
! if the character is NOT a space ' ' or a tab '->|', copy it to the output string.
         if ( curr_char /= SPACE .and. curr_char /= TAB .and. curr_char /= NUL ) then
             j = j + 1
             output(j:j) = string(i:i)
         endif ! back if block
     enddo ! over i={1,len(input_string)} loop

! copy output string to input string
     string = output

     return
  end subroutine s_str_compress

!!========================================================================
!!>>> date and time manipulation                                       <<<
!!========================================================================

!!>>> s_time_builder: returns a string containing date and time in human-readable format
  subroutine s_time_builder(date_time_string)
     implicit none

! external arguments
! output date and time
     character (len = 20), intent(out) :: date_time_string

! local variables
! used to extract data from a standard fortran call: date_and_time()
     integer :: date_time(8)

! string for current date
     character (len = 12) :: cdate

! string for current time
     character (len = 08) :: ctime

! month array
     character (len = 03) :: months(12)

! init the month array
     months( 1) = 'Jan'; months( 2) = 'Feb'; months( 3) = 'Mar'
     months( 4) = 'Apr'; months( 5) = 'May'; months( 6) = 'Jun'
     months( 7) = 'Jul'; months( 8) = 'Aug'; months( 9) = 'Sep'
     months(10) = 'Oct'; months(11) = 'Nov'; months(12) = 'Dec'

! obtain current date and time
     call date_and_time(values = date_time)

! convert date and time from integer to string
     write (cdate,'(1X,a3,1X,i2,1X,i4)') months(date_time(2)), date_time(3), date_time(1)
     write (ctime, '(i2,":",i2,":",i2)') date_time(5), date_time(6), date_time(7)

! build final output string by concating them
     date_time_string = ctime // cdate

     return
  end subroutine s_time_builder

!>>> used to print the iteration timing information about continuous time
! quantum Monte Carlo quantum impurity solver.
  subroutine s_time_analyzer(time_iter, time_niter)
     use constants

     implicit none

! external arguments
! time used in this iteration
     real(dp), intent(in) :: time_iter

! time used in total iteration
     real(dp), intent(in) :: time_niter

! local variables
! number of days
     integer  :: mday, nday

! number of hours
     integer  :: mhou, nhou

! number of minutes
     integer  :: mmin, nmin

! number of seconds
     real(dp) :: msec, nsec

     mday = time_iter / 86400
     msec = time_iter - 86400 * mday
     mhou = msec / 3600
     msec = msec - 3600 * mhou
     mmin = msec / 60
     msec = msec - 60 * mmin

     write(mystd, '(4X, ">>> used time: ")', advance = 'no')
     if ( mday > 0 ) then
         write(mystd, '(i2, " d ")', advance = 'no') mday
     endif ! back if ( mday > 0 ) block

     if ( mhou > 0 ) then
         write(mystd, '(i2, " h ")', advance = 'no') mhou
     endif ! back if ( mhou > 0 ) block

     if ( mmin > 0 ) then
         write(mystd, '(i2, " m ")', advance = 'no') mmin
     endif ! back if ( mmin > 0 ) block

     if ( msec > 0 ) then
         write(mystd, '(f5.2, " s ")', advance = 'no') msec
     endif ! back if ( msec > 0 ) block
     write(mystd, '("in current iteration.")')

     nday = time_niter / 86400
     nsec = time_niter - 86400 * nday
     nhou = nsec / 3600
     nsec = nsec - 3600 * nhou
     nmin = nsec / 60
     nsec = nsec - 60 * nmin

     write(mystd, '(4X, ">>> used time: ")', advance = 'no')
     if ( nday > 0 ) then
         write(mystd, '(i2, " d ")', advance = 'no') nday
     endif ! back if ( nday > 0 ) block

     if ( nhou > 0 ) then
         write(mystd, '(i2, " h ")', advance = 'no') nhou
     endif ! back if ( nhou > 0 ) block

     if ( nmin > 0 ) then
         write(mystd, '(i2, " m ")', advance = 'no') nmin
     endif ! back if ( nmin > 0 ) block

     if ( nsec > 0 ) then
         write(mystd, '(f5.2, " s ")', advance = 'no') nsec
     endif ! back if ( nsec > 0 ) block
     write(mystd, '("in total iteration.")')

     return
  end subroutine s_time_analyzer
