! Generic driver of the production integrator. All physical oracles live
! outside this program: it only supplies data and records actual outputs.
program rev_temporal_native
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
#ifndef REV_TEMPORAL_BASELINE
  use rd_torsion_time, only: torsion_time_report,torsion_time_get_report,torsion_time_reset, &
    torsion_time_allocate,torsion_time_mark,torsion_time_advanced,torsion_time_finish,torsion_time_plan
#endif
  use com_sec, only: nt,y
  use com_eqvlen, only: tsl
  use com_sprat, only: crat
  use com_sprat2, only: gsst
  use com_sea, only: ie
  use com_sed, only: ds
  implicit none
  integer,parameter :: ld=7,oc=6,lc=4,lt=20,cap=4097
  real(wp) :: m(ld,ld),c(ld,ld),k(ld,ld),loads(lt,lc+1)
  real(wp) :: times(cap),q(cap,oc),v(cap,oc),a(cap,oc),f(cap,oc)
  real(wp) :: t0,tf,h,hs,period,marker,ke,ratio,radius,jp,rd,tl,tr,sl,sr,unused
  real(wp) :: tqdiv1f
  integer :: dm,method,nl,nr,ntable,lind(lc),rind(oc),i,j,rows,ok,effort,use_wrapper,outcap,iq1,iq2
  integer :: unit,argc
  character(len=99) :: errmsg
  character(len=1024) :: input_file
#ifndef REV_TEMPORAL_BASELINE
  type(torsion_time_report) :: report
#endif
  argc=command_argument_count()
  if(argc/=1) stop 2
  call get_command_argument(1,input_file)
#ifndef REV_TEMPORAL_BASELINE
  if(trim(input_file)=='--fill-control') then
    call fill_control()
    stop
  end if
#endif
  open(newunit=unit,file=trim(input_file),status='old',action='read')
  read(unit,*) dm,method,nl,nr,ntable,effort,use_wrapper,outcap
  read(unit,*) t0,tf,h,hs,period,marker
  read(unit,*) ke,ratio,radius,jp
  m=0._wp;c=0._wp;k=0._wp;loads=0._wp;lind=0;rind=0
  do i=1,dm
    read(unit,*) (m(i,j),j=1,dm)
  end do
  do i=1,dm
    read(unit,*) (c(i,j),j=1,dm)
  end do
  do i=1,dm
    read(unit,*) (k(i,j),j=1,dm)
  end do
  read(unit,*) (lind(i),i=1,nl)
  read(unit,*) (rind(i),i=1,nr)
  do i=1,ntable
    read(unit,*) (loads(i,j),j=1,nl+1)
  end do
  close(unit)
  times=marker;q=marker;v=marker;a=marker;f=marker;rows=-1;errmsg=''
  ! outcap changes only the ABI-visible leading dimension, not allocation.
  ! The normal cases use cap; capacity failures have only one output column.
  if(use_wrapper==1) then
    call tnuintegu(m,c,k,dm,ntable,period,loads,lind,nl,t0,tf,h,method,rind,nr,hs,rows, &
      times,q,f,ld,oc,lt,lc,outcap,errmsg,ok)
  else
    call tnuinteg(m,c,k,dm,ntable,period,loads,lind,nl,t0,tf,h,method,rind,nr,hs,rows, &
      times,q,v,a,f,ld,oc,lt,lc,outcap,errmsg,ok)
  end if
  write(*,'(a,4(1x,i0))') 'STATE',ok,rows,nr,nl
  write(*,'(a,1x,a)') 'DIAGNOSTIC',trim(errmsg)
#ifndef REV_TEMPORAL_BASELINE
  call torsion_time_get_report(report)
  write(*,'(a,4(1x,i0),5(1x,es26.17e3))') 'REPORT',report%n_integrated,report%n_requested, &
    report%n_published,merge(1,0,report%complete),report%t_initial,report%t_final_requested, &
    report%last_integrated_time,report%last_step,report%last_published_time
  if(allocated(report%filled)) then
    write(*,'(a,*(1x,i0))') 'FILLED',(merge(1,0,report%filled(i)),i=1,size(report%filled))
  else
    write(*,'(a)') 'FILLED'
  end if
#else
  write(*,'(a)') 'REPORT_BASELINE_UNAVAILABLE'
#endif
  if(effort==1) then
    ! A unit-length circular equivalent section for the actual legacy
    ! face-torque recovery. Its constitutive values are supplied explicitly.
    nt=2;y=0._wp;y(2)=1._wp;tsl=0._wp;crat=1._wp;crat(1)=ratio
    gsst=0._wp;gsst(1)=ke/jp;ie=.5_wp*jp;ds=2._wp*radius
  end if
  iq1=0;iq2=0
  do j=1,nr
    if(rind(j)==1.and.iq1==0) iq1=j
    if(rind(j)==2.and.iq2==0) iq2=j
  end do
  do i=1,min(max(rows,0),outcap,cap)
    tl=marker;tr=marker;sl=marker;sr=marker
    if(effort==1.and.iq1>0.and.iq2>0) then
      if(q(i,iq1)/=marker.and.q(i,iq2)/=marker) then
        if(ieee_is_finite(q(i,iq1)).and.ieee_is_finite(q(i,iq2))) then
          rd=q(i,iq1)-q(i,iq2)
          unused=tqdiv1f(1,rd,tl,sl)
          unused=tqdiv1f(1,-rd,tr,sr)
        end if
      end if
    end if
    write(*,'(a,1x,i0,*(1x,es26.17e3))') 'ROW',i,times(i),q(i,1:nr),v(i,1:nr), &
      a(i,1:nr),f(i,1:nl),tl,tr,sl,sr
  end do
  ! Nonzero analysis status is recorded, rather than hiding the data in an
  ! early STOP. The external oracle decides whether a rejection was expected.
#ifndef REV_TEMPORAL_BASELINE
contains
  subroutine fill_control()
    real(wp) :: zero_values(4)
    logical :: valid(4)
    integer :: missing_ok,full_ok,local_ok,planned
    zero_values=0._wp;valid=ieee_is_finite(zero_values)
    call torsion_time_reset(0._wp,1._wp)
    call torsion_time_allocate(1,3,4)
    call torsion_time_mark(1,0._wp,valid,errmsg,local_ok)
    call torsion_time_mark(3,1._wp,valid,errmsg,local_ok)
    call torsion_time_advanced(1._wp,1._wp)
    call torsion_time_finish(errmsg,missing_ok)
    call torsion_time_get_report(report)
    write(*,'(a,3(1x,i0))') 'NATIVE_MISSING_MARK',missing_ok,merge(1,0,report%complete),report%n_published
    call torsion_time_reset(0._wp,1._wp)
    call torsion_time_allocate(1,3,4)
    call torsion_time_mark(1,0._wp,valid,errmsg,local_ok)
    call torsion_time_mark(2,.5_wp,valid,errmsg,local_ok)
    call torsion_time_mark(3,1._wp,valid,errmsg,local_ok)
    call torsion_time_advanced(1._wp,1._wp)
    call torsion_time_finish(errmsg,full_ok)
    call torsion_time_get_report(report)
    write(*,'(a,3(1x,i0))') 'NATIVE_EXACT_ZERO',full_ok,merge(1,0,report%complete),report%n_published
    if(missing_ok>=0.or.full_ok/=0.or..not.report%complete.or..not.all(report%filled)) stop 1
    call torsion_time_plan(0._wp,1.e-100_wp,1.e308_wp,planned,errmsg,local_ok)
    write(*,'(a,2(1x,i0))') 'NATIVE_TINY_SPAN',local_ok,planned
    if(local_ok/=0.or.planned/=1) stop 1
  end subroutine
#endif
end program rev_temporal_native
