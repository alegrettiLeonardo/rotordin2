program af_checked_cases
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use rd_kinds, only: lrk, wp
  implicit none
  real(lrk) :: rpg(7), x, af, nan, inf, vf(1,2), vr(1,2), vm(1,2)
  complex(wp) :: amp(1,7)
  integer :: checks, j, cn(1), ok
  character(len=1) :: st, states(1,2)
  character(len=99) :: errmsg
  logical :: found
  real(lrk), external :: fatamof

  checks = 0
  nan = ieee_value(0._lrk,ieee_quiet_nan)
  inf = ieee_value(0._lrk,ieee_positive_inf)
  call reset_curve()
  call getbds_checked(1._lrk,3,1,1,rpg,amp,5,1,7,x,found)
  call require(found,'first-interval explicit success')
  call near(x,5000._lrk/7._lrk,'first-interval crossing')
  call getbds_checked(1._lrk,3,1,-1,rpg,amp,5,1,7,x,found)
  call require(found,'last-interval explicit success')
  call near(x,23000._lrk/7._lrk,'last-interval crossing')

  amp(1,1) = cmplx(1._lrk,0._wp,wp)
  amp(1,4) = cmplx(1.25_lrk,0._wp,wp)
  amp(1,5) = cmplx(0.75_lrk,0._wp,wp)
  call getbds_checked(1._lrk,3,1,1,rpg,amp,5,1,7,x,found)
  call require(found .and. x == 0._lrk,'zero-rpm equality crossing is measured')
  af = fatamof(3,1,rpg,amp,5,1,7,st)
  call require(st == 'n','zero-rpm crossing is not mirrored')
  call near(af,4._lrk/7._lrk,'zero-rpm measured AF')
  amp(1,5) = cmplx(1._lrk,0._wp,wp)
  call getbds_checked(1._lrk,3,1,-1,rpg,amp,5,1,7,x,found)
  call require(found .and. x == 4000._lrk,'last endpoint equality crossing')
  amp(1,2) = cmplx(1._lrk,0._wp,wp)
  call getbds_checked(1._lrk,3,1,1,rpg,amp,5,1,7,x,found)
  call require(found .and. x == 1000._lrk,'interior equality selects nearest point')

  ! Left flank reverses above the target before a later low sample.
  rpg = [(100._lrk*j,j=1,7)]
  amp(1,:) = cmplx([0.4_lrk,1.35_lrk,1.3_lrk,sqrt(2._lrk),1.1_lrk,0.85_lrk,0.3_lrk],0._wp,wp)
  call getbds_checked(1._lrk,4,1,1,rpg,amp,7,1,7,x,found)
  call require(.not. found,'do not cross a reversed flank')
  af = fatamof(4,1,rpg,amp,7,1,7,st)
  call require(st == 'i','only unavailable flank is mirrored')
  call near(af,10._lrk/7._lrk,'reversal mirrored AF')
  amp(1,2) = amp(1,3)
  call getbds_checked(1._lrk,4,1,1,rpg,amp,7,1,7,x,found)
  call require(.not. found,'flat flank above target is unavailable')
  call af_interp(1._lrk,0._lrk,2._lrk,1._lrk,2._lrk,x,found)
  call require(.not. found,'zero amplitude denominator rejected')
  call af_interp(1._lrk,0._lrk,2._lrk,0._lrk,0._lrk,x,found)
  call require(.not. found,'zero speed interval rejected')

  call reset_curve()
  rpg(2) = rpg(1)
  call reject_invalid('duplicate speed')
  call reset_curve()
  rpg(2) = -1._lrk
  call reject_invalid('unordered speed')
  call reset_curve()
  rpg(2) = nan
  call reject_invalid('NaN speed')
  call reset_curve()
  rpg(2) = inf
  call reject_invalid('infinite speed')
  call reset_curve()
  amp(1,2) = cmplx(nan,0._wp,wp)
  call reject_invalid('NaN real amplitude')
  call reset_curve()
  amp(1,2) = cmplx(0._wp,inf,wp)
  call reject_invalid('infinite imaginary amplitude')
  call reset_curve()
  amp(1,2) = cmplx(huge(1._wp),huge(1._wp),wp)
  call reject_invalid('overflowing complex magnitude')

  call reset_curve()
  call getbds_checked(nan,3,1,1,rpg,amp,5,1,7,x,found)
  call require(.not. found,'nonfinite target rejected')
  call getbds_checked(1._lrk,3,1,0,rpg,amp,5,1,7,x,found)
  call require(.not. found,'invalid search direction rejected')
  call getbds_checked(1._lrk,0,1,1,rpg,amp,5,1,7,x,found)
  call require(.not. found,'invalid peak index rejected')
  call getbds_checked(1._lrk,3,2,1,rpg,amp,5,1,7,x,found)
  call require(.not. found,'invalid point index rejected')
  call getbds_checked(1._lrk,3,1,1,rpg,amp,8,1,7,x,found)
  call require(.not. found,'invalid sample count rejected')
  amp = cmplx(0._wp,0._wp,wp)
  af = fatamof(3,1,rpg,amp,5,1,7,st)
  call require(st == 'F' .and. af == -1._lrk,'zero amplitude has no AF')

  call reset_curve()
  ! Trailing capacity beyond the requested sample count is never read.
  rpg(6:7) = nan
  amp(1,6:7) = cmplx(nan,nan,wp)
  call getbds_checked(1._lrk,3,1,1,rpg,amp,5,1,7,x,found)
  call require(found,'unused capacity is not an input sample')
  call maxamp(1,2,cn,rpg,amp,vf,vr,vm,states,1,7,errmsg,ok)
  call require(ok == 0 .and. cn(1) == 0,'two valid samples produce no peak')
  call maxamp(1,1,cn,rpg,amp,vf,vr,vm,states,1,7,errmsg,ok)
  call require(ok == 0 .and. cn(1) == 0,'one valid sample produces no peak')
  write(*,'(a,i0)') 'AF_CHECKED_CASES PASS checks=',checks
contains
  subroutine reset_curve()
    rpg = [(1000._lrk*(j-1),j=1,7)]
    amp(1,:) = cmplx([0.5_lrk,1.2_lrk,sqrt(2._lrk),1.2_lrk,0.5_lrk,0._lrk,0._lrk],0._wp,wp)
  end subroutine reset_curve

  subroutine reject_invalid(label)
    character(len=*), intent(in) :: label
    call getbds_checked(1._lrk,3,1,1,rpg,amp,5,1,7,x,found)
    call require(.not. found,label//' crossing rejected')
    af = fatamof(3,1,rpg,amp,5,1,7,st)
    call require(st == 'F' .and. af == -1._lrk,label//' AF unavailable')
    call maxamp(1,5,cn,rpg,amp,vf,vr,vm,states,1,7,errmsg,ok)
    call require(ok < 0 .and. index(errmsg,'maxamp->invalid data') == 1,label//' contextual error')
  end subroutine reject_invalid

  subroutine near(actual,expected,label)
    real(lrk), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    call require(abs(actual-expected) <= 1.e-12_lrk*max(1._lrk,abs(expected)),label)
  end subroutine near

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    checks = checks+1
    if (.not. condition) then
      write(*,'(a)') 'FAIL '//label
      error stop 1
    end if
  end subroutine require
end program af_checked_cases
