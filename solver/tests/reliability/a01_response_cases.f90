! Native harmonic and Newmark kernels versus an independent 2x2 closed form.
program a01_response_cases
  use rd_kinds, only: wp,lrk
  use rd_harmonic_response, only: harmonic_response_point,harmonic_ld
  use rd_bearing_contract, only: bearing_table_reset
  use com_mat, only: mm,mg,dm
  use com_mtk, only: mk1
  use com_man, only: kxx,kxz,kzx,kzz,cxx,cxz,czx,czz,sc
  use com_tor, only: kph,kth
  use com_ymc, only: nbrg,pc
  use com_knd, only: cknd,supr
  use com_sec, only: nt,y
  use com_unb1, only: nb,ndd,mu,ed,tpf
  use com_mfa, only: au
  use com_nbc, only: cp
  use com_sp1, only: ns,bn
  use com_sp2, only: sup,sps
  use com_brgsm, only: mrp
  implicit none
  real(wp), parameter :: pi=acos(-1._wp),omega=150._wp,rpm=omega*30/pi
  complex(wp), parameter :: zi=(0._wp,1._wp)
  real(wp) :: mass(500,500),gyro(500,500),kb(500,500),cb(500,500),kp(500,500),cc(500,500)
  real(wp) :: kn(500,500),work(500,500),force(500),q(500),v(500),a(500),qn(500),vn(500),an(500),rhs(500)
  real(wp) :: period,dt,t,phase,err,errors(2),herror,maxh,maxt,orientation
  complex(wp) :: z(2,2),f(2),exact(2),det,rsp(harmonic_ld,1),fitted(2)
  integer :: ic,ip,level,nper,step,nsteps,ipiv(500),pdd(99),ddm,ok,fw,bw,runs
  character(len=99) :: msg
  period=2*pi/omega;maxh=0._wp;maxt=0._wp;fw=0;bw=0;runs=0
  do ic=1,3
    call foundation_reset()
    call bearing_table_reset()
    mm=0._lrk;mg=0._lrk;mk1=0._lrk
    nt=1;y=0._lrk;dm=4;nb=1;ndd=0._lrk;mu=0._lrk;mu(1)=0.003_lrk;tpf=0;au='R';pdd=1
    nbrg=1;pc=0._lrk;cknd='0';supr=' ';sc=1._lrk;kph=0._lrk;kth=0._lrk
    cp=0;ns=0;bn=0;sup=0._lrk;sps=1._lrk;mrp=1._lrk
    kxx=0._lrk;kxz=0._lrk;kzx=0._lrk;kzz=0._lrk
    cxx=0._lrk;cxz=0._lrk;czx=0._lrk;czz=0._lrk
    kxx(1)=8.e4_lrk;kzz(1)=8.e4_lrk;cxx(1)=30._lrk;czz(1)=30._lrk
    if(ic>=2) then
      kxx(1)=2.e4_lrk;kzz(1)=8.e4_lrk;cxx(1)=20._lrk;czz(1)=25._lrk
    end if
    if(ic==3) then
      kxz(1)=1800._lrk;kzx(1)=-1200._lrk;cxz(1)=3._lrk;czx(1)=-2._lrk
    end if
    mm(1,1)=2._lrk;mm(2,2)=2._lrk;mm(3,3)=0.01_lrk;mm(4,4)=0.01_lrk
    mk1(3,3)=2000._lrk;mk1(4,4)=2500._lrk;mg(3,4)=0.008_lrk;mg(4,3)=-0.008_lrk
    ! Reference entries are formed directly from specified model parameters.
    z(1,1)=kxx(1)-2*omega**2+zi*omega*cxx(1)
    z(2,2)=kzz(1)-2*omega**2+zi*omega*czz(1)
    z(1,2)=kxz(1)+zi*omega*cxz(1);z(2,1)=kzx(1)+zi*omega*czx(1)
    det=z(1,1)*z(2,2)-z(1,2)*z(2,1)
    do ip=0,3
      phase=ip*pi/2+0.371_wp;ed(1)=phase
      f=mu(1)*omega**2*exp(zi*phase)*[-zi,cmplx(1._wp,0._wp,wp)]
      exact(1)=(f(1)*z(2,2)-f(2)*z(1,2))/det
      exact(2)=(f(2)*z(1,1)-f(1)*z(2,1))/det
      ddm=8
      call harmonic_response_point(ddm,0,1,real(rpm,lrk),real(omega,lrk),pdd,rsp,msg,ok)
      if(ok/=0) error stop 'A01 native harmonic solve'
      herror=maxval(abs(rsp(1:2,1)-exact))/maxval(abs(exact));maxh=max(maxh,herror)
      if(herror>1.e-10_wp) error stop 'A01 harmonic versus independent closed form'
      orientation=-aimag(exact(1)*conjg(exact(2)))
      if(orientation>0._wp) fw=fw+1
      if(orientation<0._wp) bw=bw+1
      call transient_matrix_update(dm,0,rpm,omega,0._wp,mass,gyro,kb,cb,kp,cc,msg,ok)
      if(ok/=0) error stop 'A01 native physical matrix update'
      do level=1,2
        nper=200*level;dt=period/nper;nsteps=120*nper
        q=0._wp;v=0._wp;a=0._wp;force=0._wp
        call transient_unbalance_force(dm,omega,0._wp,0._wp,force,msg,ok)
        call transient_initial_acceleration(dm,500,mass,cc,kp,force,q,v,a,work,rhs,ipiv,msg,ok)
        if(ok/=0) error stop 'A01 native initial acceleration'
        call transient_newmark_factor(dm,500,mass,cc,kp,dt,0.25_wp,0.5_wp,kn,ipiv,msg,ok)
        if(ok/=0) error stop 'A01 native Newmark factor'
        fitted=cmplx(0._wp,0._wp,wp)
        do step=1,nsteps
          t=step*dt;force=0._wp
          call transient_unbalance_force(dm,omega,0._wp,omega*t,force,msg,ok)
          call transient_newmark_step(dm,500,mass,cc,dt,0.25_wp,0.5_wp,kn,ipiv,force,q,v,a,qn,vn,an,rhs,msg,ok)
          if(ok/=0) error stop 'A01 native Newmark step'
          q=qn;v=vn;a=an
          if(step>nsteps-nper) fitted=fitted+2._wp/nper*q(1:2)*exp(-zi*omega*t)
        end do
        err=maxval(abs(fitted-exact))/maxval(abs(exact));errors(level)=err;maxt=max(maxt,err)
        if(err>8.e-4_wp) error stop 'A01 complex transient/FRF tolerance'
        if((-aimag(fitted(1)*conjg(fitted(2))))*orientation<=0._wp) error stop 'A01 whirl reversal'
        runs=runs+1
        print '(a,3i4,1x,es24.16)', 'RESPONSE_CASE ',ic,ip,nper,err
      end do
      if(errors(1)/errors(2)<3.8_wp.or.errors(1)/errors(2)>4.2_wp) error stop 'A01 dt2 convergence'
    end do
  end do
  if(fw==0.or.bw==0) error stop 'A01 requires both FW and BW controls'
  print '(a,i0,a,i0,a,i0)', 'NATIVE_INTEGRATIONS=',runs,' FW=',fw,' BW=',bw
  print '(a,es24.16)', 'MAX_HARMONIC_CLOSED_FORM_ERROR=',maxh
  print '(a,es24.16)', 'MAX_TRANSIENT_COMPLEX_ERROR=',maxt
  print '(a)', 'A01_RESPONSE_WHIRL: PASS'
end program a01_response_cases
