! Independent physical-order oracle, for tests only. Production always solves
! the unchanged augmented 2n problem. This test never calls MNTMTH/PRPKC to
! construct its reference matrix and never calls LAPACK for its reference solve.
program harmonic_oracle
  use rd_kinds, only: lrk,wp
  use rd_harmonic_response, only: harmonic_response_point,harmonic_ld
  use rd_bearing_contract, only: bearing_table_reset,bearing_read_row
  use com_mat, only: mm,mg,dm
  use com_mtk, only: mk1
  use com_man, only: kxx,kxz,kzx,kzz,cxx,cxz,czx,czz,sc
  use com_tor, only: kph,kth
  use com_ymc, only: nbrg,pc
  use com_knd, only: cknd,supr
  use com_sec, only: y,nt
  use com_unb1, only: nb,mu,ed,tpf
  use com_mfa, only: au
  use com_nbc, only: cp,scl,bc
  use com_pmk, only: ntable=>nt,kmc,cmc,rmc
  use com_pmt, only: tph,tth
  use com_brgsm, only: mrp
  use com_sp1, only: ns,bn
  use com_sp2, only: sup,sps
  use com_fndctl, only: factive,fndof,fnint
  use com_fndifc, only: ficonn,fiidx,fixd,fizd
  use com_fndmat, only: fm,fk,fc
  implicit none
  integer :: ic,isp,iph,ddm,pp,fx,ok,i,j,pdd(99),solves
  real(wp), parameter :: pi=acos(-1._wp),speeds(3)=[900._wp,1800._wp,2700._wp]
  complex(wp), parameter :: zi=(0._wp,1._wp)
  real(wp) :: rpm,omega,phase,scale,den,err,kin,physical,maxerr,maxkin,maxphysical
  real(wp) :: kref(8,8),cref(8,8),kb(2,2),cb(2,2),ks(2,2),cs(2,2)
  real(wp) :: kb0(2,2),cb0(2,2)
  real(wp) :: table_values(11)
  complex(wp) :: z(8,8),force(8),expected(8),qzero(8),rsp(harmonic_ld,1),f
  character(len=99) :: errmsg
  character(len=512) :: table_line
  logical :: exists

  maxerr=0._wp; maxkin=0._wp; maxphysical=0._wp; solves=0
  kb0=reshape([1.e5_wp,-3100._wp,1700._wp,1.4e5_wp],[2,2])
  cb0=reshape([210._wp,-5._wp,7._wp,290._wp],[2,2])
  ks=reshape([3.e5_wp,-1100._wp,2300._wp,4.e5_wp],[2,2])
  cs=reshape([320._wp,-3._wp,4._wp,410._wp],[2,2])

  do ic=1,4
    call foundation_reset()
    call bearing_table_reset()
    mm=0._lrk; mg=0._lrk; mk1=0._lrk
    nbrg=1; pc=0._lrk; nt=1; y=0._lrk
    nb=3; pdd=1; mu=0._lrk; ed=0._lrk; tpf=0
    mu(1)=2.e-4_lrk; mu(2)=3.e-5_lrk
    mu(3)=100._lrk; tpf(3)=1 ! Current lateral harmonic capability: ignored.
    au='D'; cknd='0'; supr=' '; sc=1._lrk; kph=0._lrk; kth=0._lrk
    kxx=0._lrk; kxz=0._lrk; kzx=0._lrk; kzz=0._lrk
    cxx=0._lrk; cxz=0._lrk; czx=0._lrk; czz=0._lrk
    kxx(1)=kb0(1,1); kxz(1)=kb0(1,2); kzx(1)=kb0(2,1); kzz(1)=kb0(2,2)
    cxx(1)=cb0(1,1); cxz(1)=cb0(1,2); czx(1)=cb0(2,1); czz(1)=cb0(2,2)
    dm=4; pp=0; fx=1; cp=0; mrp=1._lrk
    ns=0; bn=0; sup=0._lrk; sps=1._lrk
    mk1(1,1)=2.e4_lrk; mk1(2,2)=3.e4_lrk
    mk1(3,3)=1700._lrk; mk1(4,4)=2300._lrk
    mk1(1,3)=700._lrk; mk1(3,1)=700._lrk
    mk1(2,4)=-400._lrk; mk1(4,2)=-400._lrk
    mm(1,1)=2._lrk; mm(2,2)=3._lrk
    mm(3,3)=0.011_lrk; mm(4,4)=0.013_lrk
    mg(1,2)=0.003_lrk; mg(2,1)=-0.003_lrk
    mg(3,4)=0.009_lrk; mg(4,3)=-0.009_lrk
    if(ic>=2) then
      fx=0; cknd='2'; cp=1; bc=0._lrk; bc(1)=1._lrk; scl=1._lrk
      ntable=0; ntable(1)=3; kmc=0._lrk; cmc=0._lrk; tph=0._lrk; tth=0._lrk
      do j=1,3
        rmc(1,j)=600._lrk+1200._lrk*(j-1)
        scale=1._wp+rmc(1,j)/6000._wp
        kmc(1,j,:)=[kb0(1,1),kb0(1,2),kb0(2,1),kb0(2,2)]*scale
        cmc(1,j,:)=[cb0(1,1),cb0(1,2),cb0(2,1),cb0(2,2)]*scale
        write(table_line,'(9(1x,es24.16e3))') rmc(1,j),kmc(1,j,:),cmc(1,j,:)
        call bearing_read_row(table_line,1,j,table_values,errmsg,ok)
        if(ok/=0) error stop 'native table metadata setup failed'
      end do
    end if
    if(ic>=3) then
      dm=6; pp=1; ns=1; bn(1)=1; supr='S'
      sup(1,1:4)=[ks(1,1),ks(1,2),ks(2,1),ks(2,2)]
      sup(1,5:8)=[cs(1,1),cs(1,2),cs(2,1),cs(2,2)]
      mm(5,5)=1.3_lrk; mm(6,6)=1.7_lrk
    end if
    if(ic==4) then
      dm=8; factive=.true.; fndof=2; fnint=1
      ficonn(1)=1; fiidx(1)=1; fixd(1)=1; fizd(1)=2
      fm=0._lrk; fk=0._lrk; fc=0._lrk
      fm(1,1)=5._lrk; fm(2,2)=6._lrk
      fk(1,1)=7.e5_lrk; fk(2,2)=8.e5_lrk; fk(1,2)=4500._lrk; fk(2,1)=4500._lrk
      fc(1,1)=520._lrk; fc(2,2)=610._lrk; fc(1,2)=5._lrk; fc(2,1)=5._lrk
      mm(7:8,7:8)=fm(1:2,1:2)
    end if

    do isp=1,size(speeds)
      rpm=speeds(isp); omega=rpm*pi/30._wp
      scale=1._wp
      if(ic>=2) scale=1._wp+rpm/6000._wp
      kb=kb0*scale; cb=cb0*scale
      kref=0._wp; cref=0._wp
      kref(1:4,1:4)=mk1(1:4,1:4)
      kref(1:2,1:2)=kref(1:2,1:2)+kb; cref(1:2,1:2)=cb
      if(ic>=3) then
        kref(1:2,5:6)=-kb; kref(5:6,1:2)=-kb; kref(5:6,5:6)=kb+ks
        cref(1:2,5:6)=-cb; cref(5:6,1:2)=-cb; cref(5:6,5:6)=cb+cs
      end if
      if(ic==4) then
        kref(5:6,7:8)=-ks; kref(7:8,5:6)=-ks; kref(7:8,7:8)=ks+fk(1:2,1:2)
        cref(5:6,7:8)=-cs; cref(7:8,5:6)=-cs; cref(7:8,7:8)=cs+fc(1:2,1:2)
      end if
      z(1:dm,1:dm)=kref(1:dm,1:dm)-omega**2*mm(1:dm,1:dm) &
        +zi*omega*(cref(1:dm,1:dm)+omega*mg(1:dm,1:dm))

      do iph=0,4
        phase=real(mod(iph,4),wp)*pi/2._wp
        au='D'; ed(1)=real(mod(iph,4)*90,lrk); ed(2)=ed(1)+37._lrk
        if(iph==4) then
          ! The final phase-zero repeat exercises radian input.
          au='R'; ed(1)=0._lrk; ed(2)=37._lrk*pi/180._wp
        end if
        f=omega**2*(mu(1)*cmplx(cos(phase),sin(phase),wp) &
          +mu(2)*cmplx(cos(phase+37*pi/180),sin(phase+37*pi/180),wp))
        force=0._wp; force(1)=-zi*f; force(2)=f
        call oracle_gauss(z(1:dm,1:dm),force(1:dm),expected(1:dm))
        ddm=2*dm
        call harmonic_response_point(ddm,pp,fx,real(rpm,lrk),real(omega,lrk),pdd,rsp,errmsg,ok)
        if(ok/=0) then
          print '(a)',trim(errmsg)
          error stop 'native harmonic solve failed'
        end if
        solves=solves+1
        den=maxval(abs(expected(1:dm)))
        err=maxval(abs(rsp(1:dm,1)-expected(1:dm)))/den
        if(any(abs(rsp(1:dm,1)-expected(1:dm))>1.e-12_wp+1.e-6_wp*abs(expected(1:dm)))) &
          error stop 'oracle phasor tolerance failed'
        physical=sum(abs(matmul(z(1:dm,1:dm),rsp(1:dm,1))-force(1:dm))) &
          /(maxval(sum(abs(z(1:dm,1:dm)),dim=1))*sum(abs(rsp(1:dm,1)))+sum(abs(force(1:dm))))
        kin=sum(abs(rsp(dm+1:2*dm,1)-zi*omega*rsp(1:dm,1))) &
          /(sum(abs(rsp(dm+1:2*dm,1)))+omega*sum(abs(rsp(1:dm,1))))
        if(physical>1.e-10_wp.or.kin>1.e-10_wp) error stop 'scaled residual tolerance failed'
        if(iph==0) then
          qzero(1:dm)=rsp(1:dm,1)
        else
          if(maxval(abs(rsp(1:dm,1)-exp(zi*phase)*qzero(1:dm)))>1.e-11_wp*den) &
            error stop 'common phase equivariance failed'
        end if
        maxerr=max(maxerr,err); maxphysical=max(maxphysical,physical); maxkin=max(maxkin,kin)
      end do
    end do
  end do
  inquire(file='foundation_response.csv',exist=exists)
  if(exists) error stop 'shared kernel must not create foundation output'
  print '(a,i0)', 'HARMONIC_ORACLE_SOLVES=',solves
  print '(a,es24.16e3)', 'MAX_ORACLE_RELATIVE_ERROR=',maxerr
  print '(a,es24.16e3)', 'MAX_INDEPENDENT_PHYSICAL_RESIDUAL=',maxphysical
  print '(a,es24.16e3)', 'MAX_KINEMATIC_RESIDUAL=',maxkin
  print '(a)', 'HARMONIC_ORACLE: PASS; fixed/table/cross terms/support/foundation; phases; degree/radian; KIND capability'
contains
  subroutine oracle_gauss(a,b,x)
    complex(wp), intent(in) :: a(:,:),b(:)
    complex(wp), intent(out) :: x(:)
    complex(wp) :: c(size(b),size(b)+1),row(size(b)+1),factor
    integer :: n,i,j,p
    n=size(b); c(:,1:n)=a; c(:,n+1)=b
    do j=1,n
      p=j-1+maxloc(abs(c(j:n,j)),dim=1)
      if(abs(c(p,j))<=tiny(1._wp)) error stop 'singular independent oracle'
      row=c(j,:); c(j,:)=c(p,:); c(p,:)=row
      do i=j+1,n
        factor=c(i,j)/c(j,j)
        c(i,j+1:n+1)=c(i,j+1:n+1)-factor*c(j,j+1:n+1)
      end do
    end do
    do i=n,1,-1
      x(i)=(c(i,n+1)-sum(c(i,i+1:n)*x(i+1:n)))/c(i,i)
    end do
  end subroutine oracle_gauss
end program harmonic_oracle
