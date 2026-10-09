program af_cases
  use rd_kinds, only: lrk, wp
  implicit none
  real(lrk) :: rpg(7), vf(1,2), vr(1,2), vm(1,2), af, expected, fitx, fitamp, offset
  complex(wp) :: amp(1,7), saved(1,7)
  integer :: cn(1), ok, checks, j
  character(len=1) :: st, states(1,2)
  character(len=32) :: mode
  character(len=99) :: errmsg
  real(lrk), external :: fatamof

  checks = 0
  call get_command_argument(1,mode)
  select case (trim(mode))
  case ('edge')
    rpg = [0._lrk,1000._lrk,2000._lrk,3000._lrk,4000._lrk,5000._lrk,6000._lrk]
    amp(1,:) = cmplx([0.5_lrk,1.2_lrk,sqrt(2._lrk),1.2_lrk,0.5_lrk,0._lrk,0._lrk],0._wp,wp)
    saved = amp
    af = fatamof(3,1,rpg,amp,5,1,7,st)
    write(*,'(a,es24.16,a,a)') 'EDGE AF=',af,' STATE=',st
    call require(st == 'n','first/last-interval crossings must both be measured')
    call near(af,7._lrk/9._lrk,1.e-12_lrk,'edge AF independent linear oracle')
    call maxamp(1,5,cn,rpg,amp,vf,vr,vm,states,1,7,errmsg,ok)
    call require(ok == 0 .and. cn(1) == 1,'edge maxamp peak count')
    call require(states(1,1) == 'n','edge maxamp measured status')
    call near(vf(1,1),7._lrk/9._lrk,1.e-12_lrk,'edge maxamp AF')
    call require(all(amp == saved),'edge input amplitudes unchanged')
  case ('preserved')
    rpg = [(100._lrk*j,j=1,7)]
    amp(1,:) = cmplx([0.4_lrk,0.9_lrk,1.3_lrk,sqrt(2._lrk),1.1_lrk,0.85_lrk,0.3_lrk],0._wp,wp)
    saved = amp
    af = fatamof(4,1,rpg,amp,7,1,7,st)
    expected = 400._lrk/(540._lrk-225._lrk)
    write(*,'(a,es24.16,a,a)') 'INTERIOR AF=',af,' STATE=',st
    call require(st == 'n','interior measured status')
    ! Old code used 0.70710678; allow that documented rounding here only.
    call near(af,expected,1.e-8_lrk,'interior AF preserved')
    call maxamp(1,7,cn,rpg,amp,vf,vr,vm,states,1,7,errmsg,ok)
    call require(ok == 0 .and. cn(1) == 1,'interior maxamp peak count')
    call near(vf(1,1),expected,1.e-8_lrk,'AF retains sampled Nc=400 rpm')
    offset = (1.3_lrk-1.1_lrk)/(2._lrk*(1.3_lrk-2._lrk*sqrt(2._lrk)+1.1_lrk))
    fitx = 400._lrk+100._lrk*offset
    fitamp = sqrt(2._lrk)-(1.3_lrk-1.1_lrk)*offset/4._lrk
    call near(vr(1,1),fitx,1.e-10_lrk,'quadratic peak speed oracle')
    call near(vm(1,1),fitamp,1.e-13_lrk,'quadratic peak amplitude oracle')
    call require(abs(vf(1,1)-vr(1,1)/(540._lrk-225._lrk)) > 0.05_lrk, &
      'AF must not silently switch to the fitted Nc')
    call require(all(amp == saved),'interior amplitudes unchanged')
    write(*,'(a,2es25.16)') 'PEAK_FIT ',vr(1,1),vm(1,1)

    amp(1,:) = cmplx([0.4_lrk,0.9_lrk,1.3_lrk,sqrt(2._lrk),1.2_lrk,1.1_lrk,1.05_lrk],0._wp,wp)
    af = fatamof(4,1,rpg,amp,7,1,7,st)
    call require(st == 'f','upper mirrored status retained')
    call near(af,8._lrk/7._lrk,1.e-8_lrk,'upper mirrored AF')
    amp(1,:) = cmplx([1.05_lrk,1.1_lrk,1.3_lrk,sqrt(2._lrk),1.1_lrk,0.85_lrk,0.3_lrk],0._wp,wp)
    af = fatamof(4,1,rpg,amp,7,1,7,st)
    call require(st == 'i','lower mirrored status retained')
    call near(af,10._lrk/7._lrk,1.e-8_lrk,'lower mirrored AF')
    amp = cmplx(sqrt(2._lrk),0._wp,wp)
    af = fatamof(4,1,rpg,amp,7,1,7,st)
    call require(st == 'F' .and. af == -1._lrk,'unavailable status retained')
  case default
    error stop 'usage: af_cases edge|preserved'
  end select
  write(*,'(a,a,a,i0)') 'AF_CASES PASS mode=',trim(mode),' checks=',checks
contains
  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    checks = checks+1
    if (.not. condition) then
      write(*,'(a)') 'FAIL '//label
      error stop 1
    end if
  end subroutine require

  subroutine near(actual,wanted,tolerance,label)
    real(lrk), intent(in) :: actual, wanted, tolerance
    character(len=*), intent(in) :: label
    if (abs(actual-wanted) > tolerance) then
      write(*,'(a,3es24.16)') 'actual/expected/tolerance: ',actual,wanted,tolerance
    end if
    call require(abs(actual-wanted) <= tolerance,label)
  end subroutine near
end program af_cases
