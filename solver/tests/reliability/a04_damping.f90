program a04_damping
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use com_sec, only: n,y,nt,nn
  use com_eix, only: ps
  use com_sea, only: ie,rs,gs,dely
  use com_eqvlen, only: tsl
  use com_couplings, only: ncplg,cplgid,cplgst,cplgdp,cplgin,cplgsr
  use com_dis, only: nd
  use com_conc, only: nmic
  use com_tman, only: ntbr
  use com_tmat, only: tj,tk,tc,dm
  use com_tepm, only: rfi,rlam,ddm
  use com_tmdm, only: tmd
  use com_mdamps, only: tdmrt,tdmmd,ntdmp
  implicit none
  integer,parameter :: ntime=10000
  real(wp),parameter :: dt_step=1._wp/real(ntime-1,wp)
  integer :: fails=0,checks=0,nseg,ir,im,i,j,ok,pdm,ms,ns
  real(wp) :: ratios(3),expected,ceq,keq,power,cphys(2,2),ph(2,2),m(2,2),k(2,2),c(2,2),cm(2,2)
  real(wp) :: eye(2,2),vel(500),q(500),normerr,ctot(500,500),omega,zeta,wd,t,exact,errors(3),loss,energy,work
  complex(wp) :: cf(2,2),lam(2,2),hh(2,2),d(2,2),oracle(2,2),det,zseries
  complex(wp) :: zrod,lambda,kvis,schur,diagz,offz
  character(len=99) :: msg
  real(wp) :: loads(ntime,3),times(ntime),u(ntime,2),v(ntime,2),acc(ntime,2),inload(ntime,2)
  integer :: lind(2),rind(2),nr
  ratios=[1._wp,2.5_wp,-2.5_wp]
  do im=1,2
    do ir=1,3
      do ms=0,2
        nseg=2**ms
        call fixture(nseg,ratios(ir),.false.)
        call tmatrices(im,pdm,msg,ok)
        call truth(ok==0,'native coupling assembly')
        if(ok/=0) cycle
        if(im==1.and.nseg==1) then
          write(*,'(a,5es24.16)') 'A04_ROSS_C ',ratios(ir),tc(1,1),tc(1,2),tc(2,1),tc(2,2)
        endif
        vel(1:pdm)=1._wp
        call near(maxval(abs(matmul(tc(1:pdm,1:pdm),vel(1:pdm)))),0._wp,1e-11_wp,'rigid velocity nullspace')
        call near(maxval(abs(tc(1:pdm,1:pdm)-transpose(tc(1:pdm,1:pdm)))),0._wp,1e-12_wp,'C symmetry')
        q(1:pdm)=[(real(i-1,wp)/real(pdm-1,wp),i=1,pdm)]
        power=dot_product(q(1:pdm),matmul(tc(1:pdm,1:pdm),q(1:pdm)))
        expected=4._wp*ratios(ir)**2
        call near(power,expected,1e-11_wp,'differential Rayleigh dissipation / n=1,2,4')
        call near(sum(matmul(tc(1:pdm,1:pdm),q(1:pdm))),0._wp,1e-11_wp,'internal torque balance')
        do j=1,12
          vel(1:pdm)=[(sin(real(i*j,wp)),i=1,pdm)]
          power=dot_product(vel(1:pdm),matmul(tc(1:pdm,1:pdm),vel(1:pdm)))
          call truth(power>=-1e-12_wp,'nonnegative dissipation')
        enddo
        keq=0._wp; ceq=0._wp; zseries=(0._wp,0._wp)
        do i=1,pdm-1
          keq=keq+1._wp/(-tk(i,i+1))
          ! Baseline has positive offdiagonal; record, do not divide zero.
          if(tc(i,i+1)/=0._wp) ceq=ceq+1._wp/(-tc(i,i+1))
          zseries=zseries+1._wp/cmplx(-tk(i,i+1),-7._wp*tc(i,i+1),wp)
        enddo
        call near(1._wp/keq,100._wp*ratios(ir)**2,1e-11_wp,'series coupling stiffness')
        if(ceq/=0._wp) call near(1._wp/ceq,expected,1e-11_wp,'series coupling damping')
        call near(abs(1._wp/zseries-cmplx(100._wp,28._wp,wp)*ratios(ir)**2), &
          0._wp,1e-10_wp,'massless series complex impedance at omega=7')
      enddo
    enddo
  enddo
  ! Nonuniform subdivisions require compliance weights, not their count.
  call fixture(4,1._wp,.true.)
  call tmatrices(1,pdm,msg,ok)
  call truth(ok==0,'unequal section assembly')
  ceq=0._wp
  do i=1,4
    ceq=ceq+1._wp/(-tc(i,i+1))
    call near(tc(i,i+1)/tk(i,i+1),.04_wp,1e-12_wp,'uniform relaxation time in unequal subdivisions')
  enddo
  call near(1._wp/ceq,4._wp,1e-12_wp,'unequal subdivision terminal damping')

  ! Distributed Kelvin-Voigt torsion rod: exact end impedance is
  ! (K+i*w*C)*lambda*cot(lambda), lambda=w*sqrt(J/(K+i*w*C)).
  ! Finite coupling inertia makes subdivision a mesh-convergence problem.
  kvis=cmplx(100._wp,28._wp,wp);lambda=7._wp*sqrt(.3_wp/kvis)
  zrod=kvis*lambda*cos(lambda)/sin(lambda)
  do ms=0,2
    call fixture(2**ms,1._wp,.false.)
    call tmatrices(1,pdm,msg,ok)
    schur=cmplx(tk(2,2)-49._wp*tj(2,2),7._wp*tc(2,2),wp)
    do i=3,pdm
      diagz=cmplx(tk(i,i)-49._wp*tj(i,i),7._wp*tc(i,i),wp)
      offz=cmplx(tk(i,i-1)-49._wp*tj(i,i-1),7._wp*tc(i,i-1),wp)
      schur=diagz-offz*offz/schur
    enddo
    errors(ms+1)=abs(schur-zrod)
  enddo
  call truth(errors(2)<.3_wp*errors(1).and.errors(3)<.3_wp*errors(2), &
    'distributed-inertia impedance converges quadratically for 1,2,4 subdivisions')
  write(*,'(a,3es23.15)') 'rod dynamic impedance absolute errors n=1,2,4: ',errors

#ifndef A04_BASELINE
  ! Native assembly -> existing eigensolver -> full C_modal -> FRF.
  call fixture(1,1._wp,.false.)
  call tmatrices(1,pdm,msg,ok)
  ntdmp=0
  call tespmod(msg,ok)
  call truth(ok==0,'native torsional modal solver')
  if(ok==0) then
    call tmdamp_checked(msg,ok)
    call truth(ok==0,'native mass-normalized modes accepted for damping transform')
    eye=0._wp;eye(1,1)=1._wp;eye(2,2)=1._wp
    lam=0._wp;lam(1,1)=rlam(1);lam(2,2)=rlam(2)
    cm=tmd(1:2,1:2);cf=cmplx(rfi(1:2,1:2),0._wp,wp)
    call thhmat_checked(3._wp,eye,cm,cf,lam,hh,2,0,2,2,msg,ok)
    call truth(ok==0,'native modal FRF complete chain')
    d=cmplx(tk(1:2,1:2)-9._wp*tj(1:2,1:2),3._wp*tc(1:2,1:2),wp)
    det=d(1,1)*d(2,2)-d(1,2)*d(2,1)
    oracle=reshape([d(2,2),-d(2,1),-d(1,2),d(1,1)],[2,2])/det
    call near(maxval(abs(hh-oracle)),0._wp,1e-10_wp,'native complete modal FRF vs physical 2x2 determinant')
  endif
#endif

  ! Explicit nonproportional C and a J-orthonormal rotated basis.
  ddm=2; dm=2; tj=0._wp; tk=0._wp; tc=0._wp; rfi=0._wp; rlam=0._wp
  tj(1,1)=2._wp; tj(2,2)=3._wp
  ph(:,1)=[cos(.4_wp)/sqrt(2._wp),sin(.4_wp)/sqrt(3._wp)]
  ph(:,2)=[-sin(.4_wp)/sqrt(2._wp),cos(.4_wp)/sqrt(3._wp)]
  rfi(1:2,1:2)=ph; rlam(1:2)=[25._wp,100._wp]
  cphys=reshape([3._wp,-1._wp,-1._wp,1._wp],[2,2]);tc(1:2,1:2)=cphys
  ntdmp=1; tdmmd(1)=2; tdmrt(1)=.05_wp
  call tmdamp()
  cm=matmul(transpose(ph),matmul(cphys,ph));cm(2,2)=cm(2,2)+1._wp
  call near(maxval(abs(tmd(1:2,1:2)-cm)),0._wp,1e-12_wp,'full Phi-transpose C Phi plus specified modal damping')
  call truth(abs(cm(1,2))>.1_wp,'oracle has material modal cross coupling')
  eye=0._wp;eye(1,1)=1._wp;eye(2,2)=1._wp
  lam=(0._wp,0._wp);lam(1,1)=25._wp;lam(2,2)=100._wp;cf=cmplx(ph,0._wp,wp)
  d=lam-9._wp*eye+cmplx(0._wp,3._wp,wp)*cm
  det=d(1,1)*d(2,2)-d(1,2)*d(2,1)
  oracle=reshape([d(2,2),-d(2,1),-d(1,2),d(1,1)],[2,2])/det
  oracle=matmul(cf,matmul(oracle,transpose(cf)))
#ifdef A04_BASELINE
  call thhmat(3._wp,eye,cm,cf,lam,hh,2,0,2,2)
#else
  call thhmat_checked(3._wp,eye,cm,cf,lam,hh,2,0,2,2,msg,ok)
  call truth(ok==0,'checked full modal receptance succeeds')
#endif
  call near(maxval(abs(hh-oracle)),0._wp,1e-12_wp,'full modal dynamic solve vs independent 2x2 determinant')
#ifndef A04_BASELINE
  call torsion_physical_damping(ctot,500,msg,ok)
  call truth(ok==0,'physical modal-damping pullback')
  call near(maxval(abs(matmul(transpose(ph),matmul(ctot(1:2,1:2),ph))-cm)),0._wp,1e-12_wp, &
    'transient damping returns the same complete modal matrix')
  vel(1:2)=[-sqrt(2._wp)*sin(.4_wp),sqrt(3._wp)*cos(.4_wp)]
  do j=1,2
    do i=1,2
      call near(ctot(i,j),cphys(i,j)+vel(i)*vel(j),1e-12_wp,'analytical physical modal-damping pullback')
    enddo
  enddo
  cf(:,1)=cmplx(ph(:,2),0._wp,wp)
  call thhmat_checked(3._wp,eye,cm,cf,lam,hh,2,1,2,2,msg,ok)
  oracle=matmul(reshape(cf(:,1),[2,1]),reshape(cf(:,1),[1,2]))/d(2,2)
  call truth(ok==0,'mode offset solve')
  call near(maxval(abs(hh-oracle)),0._wp,1e-12_wp,'mode offset selects both damping indices')
  cm=0._wp;lam=0._wp
  call thhmat_checked(0._wp,eye,cm,cf,lam,hh,2,0,2,2,msg,ok)
  call truth(ok<0.and.index(msg,'singular')>0,'undamped singular modal solve fails closed')
  call truth(all(abs(hh)==0._wp),'failed receptance not published')
#endif

  ! Real production transient: native 2-node consistent J, C, K assembly.
  call fixture(1,1._wp,.false.)
  call tmatrices(1,pdm,msg,ok)
  m=tj(1:2,1:2);k=tk(1:2,1:2);c=tc(1:2,1:2)
  lind=[1,2];rind=[1,2]
  do i=1,ntime
    loads(i,:)=[real(i-1,wp)*dt_step,1._wp,-1._wp]
  enddo
  ! For q=[x,-x], J_modal equation: .05*xdd+8*xd+200*x=1.
  ! This fixture is overdamped; exact step response from scalar roots.
  do im=0,1
    times=0._wp;u=0._wp;v=0._wp;acc=0._wp;inload=0._wp;nr=0
    call tnuinteg(m,c,k,2,ntime,1._wp,loads,lind,2,0._wp,1._wp,dt_step,im,rind,2,dt_step,nr, &
      times,u,v,acc,inload,2,2,ntime,2,ntime,msg,ok)
    call truth(ok==0,'native transient Newmark/Wilson')
    call truth(nr==ntime,'native transient result count')
    call near(times(nr),1._wp,1e-12_wp,'advertised final time')
    call near(u(nr,1),step_exact(1._wp,.05_wp,8._wp,200._wp),2e-6_wp,'final displacement row actually computed')
    normerr=0._wp
    do i=1,nr
      t=times(i)
      exact=step_exact(t,.05_wp,8._wp,200._wp)
      normerr=max(normerr,abs(u(i,1)-exact),abs(u(i,2)+exact))
    enddo
    call near(normerr,0._wp,2e-6_wp,'native transient vs analytic overdamped step')
    call truth(all(ieee_is_finite(u)).and.all(ieee_is_finite(v)).and.all(ieee_is_finite(acc)),'finite transient arrays')
    loss=0._wp
    do i=2,nr
      loss=loss+.5_wp*(times(i)-times(i-1))*(dot_product(v(i,:),matmul(c,v(i,:)))+ &
        dot_product(v(i-1,:),matmul(c,v(i-1,:))))
    enddo
    energy=.5_wp*(dot_product(v(nr,:),matmul(m,v(nr,:)))+dot_product(u(nr,:),matmul(k,u(nr,:))))
    work=u(nr,1)-u(nr,2)
    call near(energy+loss,work,1e-7_wp,'transient work equals stored plus dissipated energy')
    write(*,'(a,i0,a,es13.5,a,3es13.5)') 'transient method=',im,' max error=',normerr, &
      ' stored/dissipated/work=',energy,loss,work
  enddo
  write(*,'(a,i0,a,i0)') 'A04 checks=',checks,' failures=',fails
  if(fails>0) stop 1
contains
  subroutine fixture(ns,ratio,unequal)
    integer,intent(in)::ns
    real(wp),intent(in)::ratio
    logical,intent(in)::unequal
    integer::a
    n=0._wp;n(1)=real(ns,wp);nt=ns+1;nn=1;y=0._wp;tsl=0._wp
    do a=1,ns+1
      y(a)=real(a-1,wp)/real(ns,wp)
    enddo
    if(unequal) y(1:5)=[0._wp,.1_wp,.3_wp,.6_wp,1._wp]
    ie=.5_wp;rs=1._wp;gs=1._wp;dely=1._wp/real(ns,wp);ps=0._wp;ps(1)=1._wp
    nd=0;ntbr=0;nmic=0;ncplg=1;cplgid(1)=1;cplgst(1)=100._wp;cplgdp(1)=4._wp
    cplgin(1)=.3_wp;cplgsr(1)=ratio
  end subroutine
  real(wp) function step_exact(t,m,c,k) result(x)
    real(wp),intent(in)::t,m,c,k
    real(wp)::r1,r2
    r1=(-c+sqrt(c*c-4*m*k))/(2*m);r2=(-c-sqrt(c*c-4*m*k))/(2*m)
    x=(1._wp+(r2*exp(r1*t)-r1*exp(r2*t))/(r1-r2))/k
  end function
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
