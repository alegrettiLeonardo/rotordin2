!> Explicit time grids and publication accounting for torsional transients.
module rd_torsion_time
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: error_unit
  implicit none
  private
  type, public :: torsion_time_report
    integer :: n_planned=0,n_integrated=0,n_requested=0,n_published=0
    real(wp) :: t_initial=0._wp,t_final_requested=0._wp,last_integrated_time=0._wp,last_step=0._wp
    real(wp) :: last_published_time=0._wp
    logical :: complete=.false.
    logical,allocatable :: filled(:),channel_filled(:,:)
  end type
  type(torsion_time_report),save :: current
  logical,save :: deferred=.false.
  public :: torsion_time_get_report,torsion_time_reset,torsion_time_plan,torsion_time_grid
  public :: torsion_time_next,torsion_time_allocate,torsion_time_mark,torsion_time_advanced,torsion_time_finish
  public :: torsion_time_emit_report,torsion_time_check_table
  public :: torsion_time_defer,torsion_time_is_deferred,torsion_time_invalidate
contains
  subroutine torsion_time_defer(value)
    logical,intent(in) :: value
    deferred=value
  end subroutine

  logical function torsion_time_is_deferred()
    torsion_time_is_deferred=deferred
  end function

  subroutine torsion_time_invalidate()
    current%complete=.false.
  end subroutine

  subroutine torsion_time_emit_report()
    write(error_unit,'(a,i0,a,es24.16,a,i0,a,i0,a,es24.16,a,i0,a,i0,a,l1)') &
      'RD_TORSION_TIME INTEGRATED=',current%n_integrated,' LAST_INTEGRATED=',current%last_integrated_time, &
      ' REQUESTED=',current%n_requested,' PUBLISHED=',current%n_published, &
      ' LAST_PUBLISHED=',current%last_published_time,' VALID_ROWS=',count(current%filled), &
      ' VALID_CHANNELS=',count(current%channel_filled),' COMPLETE=',current%complete
  end subroutine

  ! Conservative representable-intermediate domain for the unchanged natural
  ! spline and the caller's time-delta statistics. No absolute time tolerance.
  subroutine torsion_time_check_table(times,n,amplitude,errmsg,ok)
    integer,intent(in) :: n
    real(wp),intent(in) :: times(n),amplitude
    character(*),intent(out) :: errmsg
    integer,intent(out) :: ok
    real(wp) :: dmin,dmax,delta,span,bound
    integer :: i
    ok=-1;errmsg=' '
    if(n<2) then
      errmsg='REV-01 load grid: at least two time points required';return
    end if
    if(.not.all(ieee_is_finite(times)).or..not.ieee_is_finite(amplitude)) then
      errmsg='REV-01 load grid: finite time points and loads required';return
    end if
    if(times(n)<=times(1)) then
      errmsg='REV-01 load grid: positive span required';return
    end if
    if(times(1)<0._wp.and.times(n)>0._wp) then
      if(times(n)>huge(1._wp)+times(1)) then
        errmsg='REV-01 load grid: time differences exceed real64 range';return
      end if
    end if
    span=times(n)-times(1)
    if(span>sqrt(huge(1._wp))/(4._wp*sqrt(real(n,wp)))) then
      errmsg='REV-01 load grid: spline/statistics time products exceed real64 range';return
    end if
    dmin=span;dmax=0._wp
    do i=2,n
      if(times(i)<=times(i-1)) then
        errmsg='REV-01 load grid: times must be strictly increasing';return
      end if
      delta=times(i)-times(i-1)
      dmin=min(dmin,delta);dmax=max(dmax,delta)
    end do
    if(dmin<sqrt(8._wp/huge(1._wp))) then
      errmsg='REV-01 load grid: spline divisors exceed real64 range';return
    end if
    if(amplitude>0._wp) then
      bound=log(amplitude)+2._wp*max(0._wp,log(dmax))-2._wp*min(0._wp,log(dmin)) &
        +log(128._wp*real(n,wp))
      if(bound>log(huge(1._wp))) then
        errmsg='REV-01 load grid: spline load/time products exceed real64 range';return
      end if
    end if
    ok=0
  end subroutine

  subroutine torsion_time_get_report(report)
    type(torsion_time_report),intent(out) :: report
    report=current
  end subroutine

  subroutine torsion_time_reset(t0,tf)
    real(wp),intent(in) :: t0,tf
    current%n_planned=0;current%n_integrated=0;current%n_requested=0;current%n_published=0
    current%t_initial=t0;current%t_final_requested=tf;current%last_integrated_time=t0;current%last_step=0._wp
    current%complete=.false.;current%last_published_time=t0
    if(allocated(current%filled)) deallocate(current%filled)
    if(allocated(current%channel_filled)) deallocate(current%channel_filled)
    allocate(current%filled(0),current%channel_filled(0,0))
  end subroutine

  ! Positive duration; a true final fraction is integrated, not rounded away.
  ! Only a quotient within its floating-point rounding envelope of a positive
  ! integer is snapped. There is no fixed tolerance measured in seconds.
  subroutine torsion_time_plan(t0,tf,dt,nsteps,errmsg,ok)
    real(wp),intent(in) :: t0,tf,dt
    integer,intent(out) :: nsteps,ok
    character(*),intent(out) :: errmsg
    real(wp) :: span,ratio,limit,tol,offset
    integer :: nearest
    logical :: exact_endpoint
    nsteps=0;ok=-1;errmsg=' '
    if(.not.ieee_is_finite(t0).or..not.ieee_is_finite(tf).or..not.ieee_is_finite(dt)) then
      errmsg='REV-01 time grid: finite t0, tf and step required';return
    end if
    if(tf<=t0.or.dt<=0._wp) then
      errmsg='REV-01 time grid: require tf > t0 and step > 0';return
    end if
    if(t0<0._wp.and.tf>0._wp) then
      if(tf>huge(1._wp)+t0) then
        errmsg='REV-01 time grid: elapsed duration exceeds real64 range';return
      end if
    end if
    span=tf-t0
    ! A larger nominal step still executes one representable residual step.
    ! Avoid a quotient that may underflow to zero before CEILING.
    if(dt>=span) then
      nsteps=1;ok=0;return
    end if
    limit=real(huge(1)-2,wp)
    if(dt<=huge(1._wp)/limit) then
      if(span>limit*dt) then
        errmsg='REV-01 time grid: number of increments exceeds integer capacity';return
      end if
    end if
    ratio=span/dt
    nearest=nint(ratio)
    tol=8._wp*epsilon(1._wp)*max(1._wp,abs(ratio))
    exact_endpoint=.false.
    if(nearest>0) then
      if(dt<=huge(1._wp)/real(nearest,wp)) then
        offset=real(nearest,wp)*dt
        if(offset<=huge(1._wp)-max(t0,0._wp)) exact_endpoint=t0+offset==tf
      end if
    end if
    if(nearest>0.and.(exact_endpoint.or.abs(ratio-real(nearest,wp))<=tol)) then
      nsteps=nearest
    else
      nsteps=ceiling(ratio)
    end if
    if(nsteps<1) then
      errmsg='REV-01 time grid: no representable positive increment';return
    end if
    if(nsteps>1) then
      if(dt<max(spacing(t0),spacing(tf)).or.t0+dt<=t0) then
        errmsg='REV-01 time grid: step cannot advance the absolute time in real64';return
      end if
    end if
    ok=0
  end subroutine

  subroutine torsion_time_grid(t0,tf,dt,capacity,nrows,times,errmsg,ok)
    real(wp),intent(in) :: t0,tf,dt
    integer,intent(in) :: capacity
    integer,intent(out) :: nrows,ok
    real(wp),intent(out) :: times(capacity)
    character(*),intent(out) :: errmsg
    integer :: nsteps,i
    nrows=0;ok=-1;errmsg=' '
    call torsion_time_plan(t0,tf,dt,nsteps,errmsg,ok)
    if(ok/=0) return
    ok=-1
    if(nsteps>=capacity) then
      errmsg='REV-01 time grid: requested output exceeds result capacity';return
    end if
    nrows=nsteps+1
    times(1)=t0
    do i=2,nrows-1
      times(i)=t0+real(i-1,wp)*dt
    end do
    times(nrows)=tf
    do i=2,nrows
      if(times(i)<=times(i-1)) then
        nrows=0;errmsg='REV-01 time grid: output times are not distinctly representable';return
      end if
    end do
    ok=0
  end subroutine

  subroutine torsion_time_next(t0,tf,dt,index,nsteps,previous,next,h,errmsg,ok)
    real(wp),intent(in) :: t0,tf,dt,previous
    integer,intent(in) :: index,nsteps
    real(wp),intent(out) :: next,h
    character(*),intent(out) :: errmsg
    integer,intent(out) :: ok
    ok=-1;errmsg=' ';next=previous;h=0._wp
    if(index<1.or.index>nsteps) then
      errmsg='REV-01 time grid: invalid integration index';return
    end if
    if(index==nsteps) then
      next=tf
    else
      next=t0+real(index,wp)*dt
    end if
    h=next-previous
    if(next<=previous.or.h<=0._wp.or.next>tf) then
      errmsg='REV-01 time grid: increment does not advance within [t0,tf]';return
    end if
    ok=0
  end subroutine

  subroutine torsion_time_allocate(nsteps,nrows,nchannels)
    integer,intent(in) :: nsteps,nrows,nchannels
    current%n_planned=nsteps;current%n_requested=nrows
    if(allocated(current%filled)) deallocate(current%filled)
    if(allocated(current%channel_filled)) deallocate(current%channel_filled)
    allocate(current%filled(nrows),current%channel_filled(nrows,nchannels))
    current%filled=.false.;current%channel_filled=.false.
  end subroutine

  subroutine torsion_time_mark(row,time,valid,errmsg,ok)
    integer,intent(in) :: row
    real(wp),intent(in) :: time
    logical,intent(in) :: valid(:)
    character(*),intent(out) :: errmsg
    integer,intent(out) :: ok
    ok=-1;errmsg=' '
    if(row<1.or.row>current%n_requested) then
      errmsg='REV-02 publication: invalid output row';return
    end if
    if(size(valid)/=size(current%channel_filled,2)) then
      errmsg='REV-02 publication: channel accounting mismatch';return
    end if
    if(current%filled(row)) then
      errmsg='REV-02 publication: output row would be published twice';return
    end if
    current%channel_filled(row,:)=valid
    if(.not.all(valid)) then
      write(errmsg,'(a,i0)') 'REV-02 publication: nonfinite or missing channel at output row ',row
      return
    end if
    current%last_published_time=time
    current%filled(row)=.true.
    current%n_published=current%n_published+1
    ok=0
  end subroutine

  subroutine torsion_time_advanced(time,h)
    real(wp),intent(in) :: time,h
    current%n_integrated=current%n_integrated+1
    current%last_integrated_time=time;current%last_step=h
  end subroutine

  subroutine torsion_time_finish(errmsg,ok)
    character(*),intent(out) :: errmsg
    integer,intent(out) :: ok
    ok=-1;errmsg=' ';current%complete=.false.
    if(current%n_integrated/=current%n_planned.or.current%n_planned<1) then
      errmsg='REV-01 completion: not all planned increments were integrated';return
    end if
    if(current%last_integrated_time/=current%t_final_requested) then
      errmsg='REV-01 completion: integration did not reach requested tf';return
    end if
    if(current%n_published/=current%n_requested.or.current%n_requested<2) then
      write(errmsg,'(a,i0,a,i0)') 'REV-02 completion: published ',current%n_published,' of ',current%n_requested
      return
    end if
    if(.not.all(current%filled).or..not.all(current%channel_filled)) then
      errmsg='REV-02 completion: incomplete output row/channel markers';return
    end if
    if(current%last_published_time/=current%t_final_requested) then
      errmsg='REV-02 completion: last published time differs from tf';return
    end if
    current%complete=.true.;ok=0
  end subroutine
end module rd_torsion_time
