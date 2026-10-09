! Independent countercases: production tnuinteg, no math or I/O stubs.
! J=1, C=K=0, T(t)=1, q0=v0=0 -> q(t)=t^2/2, v(t)=t, a(t)=1.
program review_time_grid
  use rd_kinds, only: wp
  implicit none
  integer,parameter :: cap=2001
  real(wp) :: jmat(1,1),cmat(1,1),kmat(1,1),loads(3,2)
  real(wp) :: times(cap),u(cap,1),v(cap,1),a(cap,1),inputloads(cap,1)
  real(wp) :: finish,dt,dtout,expected,error,ratio
  integer :: caseid,method,nr,ok,k,lind(1),rind(1),failures
  character(len=99) :: msg
  character(len=28) :: label
  jmat=1._wp; cmat=0._wp;kmat=0._wp;lind=1;rind=1;failures=0
  do caseid=1,4
    select case(caseid)
    case(1)
      label='aligned_control';finish=.01_wp;dt=.001_wp;dtout=.001_wp
    case(2)
      label='output_four_times_finer';finish=.01_wp;dt=.001_wp;dtout=.00025_wp
    case(3)
      label='roundoff_0p3_div_0p1';finish=.3_wp;dt=.1_wp;dtout=.1_wp
    case(4)
      label='roundoff_0p29_div_0p01';finish=.29_wp;dt=.01_wp;dtout=.01_wp
    end select
    ratio=finish/dt
    do method=0,1
      loads(:,1)=[0._wp,finish/2,finish];loads(:,2)=1._wp
      times=0._wp;u=0._wp;v=0._wp;a=0._wp;inputloads=0._wp;nr=0;msg=''
      call tnuinteg(jmat,cmat,kmat,1,3,finish,loads,lind,1,0._wp,finish,dt,method,rind,1,&
        dtout,nr,times,u,v,a,inputloads,1,1,3,1,cap,msg,ok)
      expected=finish**2/2
      error=maxval(abs(u(1:nr,1)-.5_wp*times(1:nr)**2))
      write(*,'(a,a,a,i0,a,i0,a,i0)') 'CASE=',trim(label),' METHOD=',method,' OK=',ok,' ROWS=',nr
      write(*,'(a,es25.17,a,i0)') 'T_OVER_DT=',ratio,' INTEGER_TRUNCATION=',int(ratio)
      write(*,'(a,4(es25.17,1x))') 'LAST_T_Q_V_A=',times(nr),u(nr,1),v(nr,1),a(nr,1)
      write(*,'(a,es25.17,a,es25.17)') 'EXPECTED_FINAL_Q=',expected,' MAX_Q_ERROR=',error
      write(*,'(a,i0)') 'UNWRITTEN_POSITIVE_TIME_Q_ROWS=',count(times(2:nr)>0._wp.and.u(2:nr,1)==0._wp)
      if(ok/=0 .or. error>1e-10_wp .or. abs(times(nr)-finish)>1e-12_wp) then
        failures=failures+1;write(*,'(a,a)') 'COUNTERCASE_FAIL ',trim(label)
      else
        write(*,'(a,a)') 'CONTROL_PASS ',trim(label)
      end if
      if(len_trim(msg)>0) write(*,'(a)') trim(msg)
    end do
  end do
  write(*,'(a,i0)') 'INDEPENDENT_GRID_FAILURES=',failures
end program review_time_grid
