program a05_acceleration
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite,ieee_value,ieee_quiet_nan,ieee_positive_inf
  implicit none
  integer :: checks=0,fails=0,ok,sgn,i,j,imt,ipiv(2),info
  real(wp)::m(2,2),k(2,2),c(2,2),q(2),v(2),f(2),a0(2),wanted(2),res(2),energy,prev,dt,t
  real(wp)::a(0:8),tet,ke(2,2),pp(2),fo(2),fn(2),uu(2),un(2),vn(2),wn(2),exactq,exactv,exacta
  real(wp)::eta,loads(3,3),times(11),ur(11,2),vr(11,2),ar(11,2),fr(11,2),scale_f,loss,oldv
  integer::li(2),ri(2),nr
  character(len=99)::msg
  do sgn=-1,1,2
    m=0._wp;k=0._wp;c=0._wp;q=0._wp;v=0._wp;f=0._wp
    m(1,1)=1._wp;c(1,1)=2._wp;v(1)=real(sgn,wp)
    call accel0f(m,k,c,q,v,f,1,2,a0,msg,ok)
    call truth(ok==0,'scalar initial equilibrium solved')
    call near(a0(1),-2._wp*sgn,1e-13_wp,'mandatory damping-sign countercase +/- velocity')
    write(*,'(a,2es23.15)') 'A05_SCALAR_INITIAL ',v(1),a0(1)
  enddo
  m=reshape([2._wp,.3_wp,.3_wp,1._wp],[2,2]);k=reshape([5._wp,-2._wp,-2._wp,3._wp],[2,2])
  c=reshape([.7_wp,-.2_wp,-.2_wp,.4_wp],[2,2]);q=[.4_wp,-.1_wp];v=[.2_wp,-.6_wp];f=[1._wp,2._wp]
  res=f-matmul(k,q)-matmul(c,v)
  wanted=[m(2,2)*res(1)-m(1,2)*res(2),m(1,1)*res(2)-m(2,1)*res(1)]/(m(1,1)*m(2,2)-m(1,2)*m(2,1))
  call accel0f(m,k,c,q,v,f,2,2,a0,msg,ok)
  call truth(ok==0,'coupled nonzero displacement velocity load solve')
  call near(maxval(abs(a0-wanted)),0._wp,1e-13_wp,'coupled acceleration versus independent 2x2 determinant')
  call near(maxval(abs(matmul(m,a0)+matmul(c,v)+matmul(k,q)-f)),0._wp,1e-13_wp,'physical initial residual')
  write(*,'(a,2es23.15)') 'A05_COUPLED_ACCELERATION ',a0
#ifndef A05_BASELINE
  call torsion_initial_residual(m,k,c,q,v,f,a0,2,2,2,eta,ok)
  call truth(ok==0,'physical residual helper accepts correct acceleration')
  call near(eta,0._wp,1e-13_wp,'normalized physical residual')
  a0(1)=a0(1)+.1_wp
  call torsion_initial_residual(m,k,c,q,v,f,a0,2,2,2,eta,ok)
  call truth(ok<0.and.eta>1e-3_wp,'physical residual fails closed for injected wrong acceleration')
#endif
  do i=1,2
    m=0._wp;k=0._wp;c=0._wp;q=0._wp;v=0._wp;f=0._wp;m(1,1)=3._wp
    if(i==1) then
      k(1,1)=6._wp;q(1)=.1_wp;wanted(1)=-.2_wp
    else
      f(1)=.6_wp;wanted(1)=.2_wp
    endif
    call accel0f(m,k,c,q,v,f,1,2,a0,msg,ok)
    call truth(ok==0,'displacement-only/load-only initial state')
    call near(a0(1),wanted(1),1e-13_wp,'isolated elastic and applied initial torque signs')
  enddo
  ! Scalar rescaling must not alter acceleration or singularity decisions.
  do j=-1,1,2
    scale_f=10._wp**(100*j)
    m=0._wp;k=0._wp;c=0._wp;q=0._wp;v=0._wp;f=0._wp
    m(1,1)=scale_f;c(1,1)=2._wp*scale_f;v(1)=1._wp
    call accel0f(m,k,c,q,v,f,1,2,a0,msg,ok)
    call truth(ok==0,'uniform inertia/torque rescaling')
    call near(a0(1),-2._wp,1e-13_wp,'acceleration invariant under 1e+/-100 scaling')
  enddo
  ! Complete free-decay integration through production numerical kernels.
  ! No test-only state update equations; analytic exp(-2t) is independent.
  do imt=0,1
    m=0._wp;k=0._wp;c=0._wp;q=0._wp;v=0._wp;f=0._wp
    m(1,1)=1._wp;c(1,1)=2._wp;v(1)=1._wp
    call accel0f(m,k,c,q,v,f,1,2,a0,msg,ok)
    dt=.001_wp
    call itegcte(imt,dt,a,tet,8)
    call effstif(k,m,c,a(0),a(1),1,2,ke)
    call dgetrf(1,1,ke,2,ipiv,info)
    call truth(info==0,'effective system factorization')
    energy=.5_wp;fo=f;loss=0._wp;un=0._wp;vn=0._wp;wn=0._wp
    do i=1,1000
      oldv=v(1)
      call tforvec(m,c,q,v,a0,a,f,fo,fn,pp,tet,imt,1,2,8)
      uu=pp
      call dgetrs('N',1,1,ke,2,ipiv,uu,1,info)
      call newdisp(uu,q,v,a0,un,vn,wn,a,dt,imt,1,2,8)
      q=un;v=vn;a0=wn;fo=fn
      prev=energy;energy=.5_wp*v(1)**2
      loss=loss+dt*(oldv**2+v(1)**2)
      call truth(energy<=prev+1e-13_wp,'passive free-decay kinetic energy')
    enddo
    exactv=exp(-2._wp);exactq=(1._wp-exactv)/2._wp;exacta=-2._wp*exactv
    call near(q(1),exactq,1e-6_wp,'free decay displacement analytic')
    call near(v(1),exactv,1e-6_wp,'free decay velocity analytic')
    call near(a0(1),exacta,2e-6_wp,'free decay acceleration analytic')
    call near(energy+loss,.5_wp,1e-6_wp,'initial kinetic energy equals remaining plus dissipated energy')
    write(*,'(a,i0,a,3es23.15)') 'A05_FREE_DECAY method=',imt,' q/v/a=',q(1),v(1),a0(1)
  enddo
  ! Complete production tnuinteg route, intentionally different input and
  ! output leading dimensions (the real wrapper uses 10000 vs 50000).
  m=0._wp;k=0._wp;c=0._wp;m(1,1)=2._wp;m(2,2)=3._wp;c(1,1)=4._wp;c(2,2)=6._wp
  loads(:,1)=[0._wp,.005_wp,.01_wp];loads(:,2)=8._wp;loads(:,3)=9._wp;li=[1,2];ri=[1,2]
  times=0._wp;ur=0._wp;vr=0._wp;ar=0._wp;fr=0._wp;nr=0
  call tnuinteg(m,c,k,2,3,.01_wp,loads,li,2,0._wp,.01_wp,.001_wp,0,ri,2,.001_wp,nr, &
    times,ur,vr,ar,fr,2,2,3,2,11,msg,ok)
  call truth(ok==0,'complete native transient route')
  call near(ar(1,1),4._wp,1e-13_wp,'first initial acceleration column published')
  call near(ar(1,2),3._wp,1e-13_wp,'second initial acceleration column uses actual output leading dimension')
  call near(times(nr),.01_wp,1e-14_wp,'complete native transient final time')
  call near(vr(nr,1),2._wp*(1._wp-exp(-.02_wp)),1e-7_wp,'native velocity versus analytic forced viscous system')
  call near(vr(nr,2),1.5_wp*(1._wp-exp(-.02_wp)),1e-7_wp,'native second DOF velocity versus analytic system')
  call truth(all(ieee_is_finite(ur)).and.all(ieee_is_finite(vr)).and.all(ieee_is_finite(ar)), &
    'finite full native transient results')
  write(*,'(a,2es23.15)') 'A05_NATIVE_INITIAL_ACCELERATION ',ar(1,:)
  m=0._wp;k=0._wp;c=0._wp;q=0._wp;v=0._wp;f=0._wp;f(1)=1._wp
  a0=99._wp
  call accel0f(m,k,c,q,v,f,2,2,a0,msg,ok)
  call truth(ok<0,'singular inertia rejected')
#ifndef A05_BASELINE
  call truth(all(a0==0._wp),'failed acceleration is not published')
  call truth(index(msg,'singular')>0.and.index(msg,'accel0f')>0,'singular diagnostic context')
  m(1,1)=1._wp;m(2,2)=1e-18_wp
  call accel0f(m,k,c,q,v,f,2,2,a0,msg,ok)
  call truth(ok<0.and.index(msg,'condition')>0,'numerically singular inertia fails closed')
  m(2,2)=1._wp;f(1)=ieee_value(0._wp,ieee_quiet_nan)
  call accel0f(m,k,c,q,v,f,2,2,a0,msg,ok)
  call truth(ok<0.and.index(msg,'finite')>0,'NaN load rejected without arithmetic')
  f=0._wp;m(1,1)=ieee_value(0._wp,ieee_positive_inf)
  call accel0f(m,k,c,q,v,f,2,2,a0,msg,ok)
  call truth(ok<0.and.index(msg,'finite')>0,'Inf inertia rejected without arithmetic')
  call accel0f(m,k,c,q,v,f,0,2,a0,msg,ok)
  call truth(ok<0.and.index(msg,'dimension')>0,'invalid dimensions rejected')
  m=0._wp;k=0._wp;c=0._wp;q=0._wp;v=0._wp;f=0._wp
  m(1,1)=1e308_wp;k(1,1)=1e308_wp;q(1)=2._wp
  call accel0f(m,k,c,q,v,f,1,2,a0,msg,ok)
  call truth(ok<0.and.index(msg,'real64 range')>0,'finite elastic overflow diagnosed before Debug arithmetic trap')
  call truth(all(a0==0._wp),'overflow-range failure publishes no acceleration')
  k=0._wp;q=0._wp;c(1,1)=1e308_wp;v(1)=2._wp
  call accel0f(m,k,c,q,v,f,1,2,a0,msg,ok)
  call truth(ok<0.and.index(msg,'damping torque')>0,'finite damping overflow diagnosed before Debug arithmetic trap')
#endif
  write(*,'(a,i0,a,i0)') 'A05 checks=',checks,' failures=',fails
  if(fails>0) stop 1
contains
  subroutine truth(test,label)
    logical,intent(in)::test
    character(*),intent(in)::label
    checks=checks+1
    if(.not.test) then
      fails=fails+1;write(*,'(a)') 'FAIL '//label
    endif
  end subroutine
  subroutine near(got,want,tol,label)
    real(wp),intent(in)::got,want,tol
    character(*),intent(in)::label
    call truth(ieee_is_finite(got).and.abs(got-want)<=tol,label)
    if(.not.ieee_is_finite(got).or.abs(got-want)>tol) write(*,'(a,3es23.15)') 'got/want/tol ',got,want,tol
  end subroutine
end program
