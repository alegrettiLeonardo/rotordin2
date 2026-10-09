! Synthetic RD2-01 controls. These are not the absent historical ST41 decks.
! Native production PREDAD/assembly routines, independent polynomial integrals.
program geometry_regression
  use rd_kinds, only: lrk, wp
  use com_eix, only: cs, l, ps, d, di, e, nu, rho_e, g_e
  use com_eixshape, only: etype, d2, di2
  use com_eixa, only: divs, umps
  use com_sec, only: n, y, nt, nn
#ifndef ST41_BASELINE
  use com_sec, only: elemsec
#endif
  use com_sea, only: s, ie, rs, es, gs, ump, dely
  use com_seaf, only: dfc, dfa
  use com_sed, only: ds, di_s
  use com_seg, only: gfc
  use com_dis, only: nd, pd, d_d, h_d, rho_d
  use com_disa, only: m_d, i_x, i_y, d_i
  use com_dsc, only: md, idx, idy
  use com_doff, only: off_d
  use com_dflexi, only: dmodel
  use com_conc, only: nmic, psic, vlmc, ixic, iyic, izic
  use com_unb0, only: np, pr, desp, ori
  use com_unb1, only: nb, ndd, mu, ed, tpf
  use com_ymc, only: nbrg, pc
  use com_man, only: kxx, kxz, kzx, kzz, cxx, cxz, czx, czz, bmass => mm, bscale => sc
  use com_tman, only: ntbr, tpc, tkk, tcc, tjj
  use com_pse, only: v_maior, v_menor
  use com_psea, only: ld_r
  use com_gycsedc, only: ngycsed, gycsedid, gycsedvl
  use com_mfa, only: au
  use com_sp1, only: ns
  use com_knd, only: cknd, supr
  use com_eqvlen, only: teql, tsl
  use com_divinf, only: sdv, sde
  use com_fillets, only: ntfil, tfilid, tfilrd
  use com_couplings, only: ncplg, cplgid, cplgst, cplgin, cplgdp, cplgsr
  use com_mat, only: mm, mg, dm
  use com_mbk, only: mkb
  use com_mtk, only: mk1
  use com_tmat, only: tj, tk, tc
  implicit none
  character(len=32) :: scenario
  character(len=99) :: errmsg
  integer :: failures=0, checks=0, ok, i, j, k, level, pp, pdm, im
  integer :: prs(9), inddis, indypf, indsecf
  real(lrk) :: py(9), truth(6), src(6), mesh(6), err(3), cm, refcm, tsum, expected, statol
  real(lrk) :: disforf, trextf, left, right, rad
  complex(wp) :: response(4,3)
  call get_command_argument(1,scenario)
  statol=2e-13_lrk
  call reset_case()
  select case(trim(scenario))
  case('compare_responses')
    call compare_response_logs()
  case('boundary')
    cs=4
    l=2._lrk
    ps(1:cs)=[0.75_lrk,1.25_lrk,1.2506_lrk,2._lrk]
    d(1:cs)=[0.08_lrk,0.1_lrk,0.06_lrk,0.04_lrk]
    d2=d
    e(1:cs)=[207e9_lrk,70e9_lrk,110e9_lrk,180e9_lrk]
    rho_e(1:cs)=[7800._lrk,2700._lrk,4500._lrk,8000._lrk]
    nu(1:cs)=[0.30_lrk,0.29_lrk,0.27_lrk,0.32_lrk]
    divs(1:cs)=[4,3,1,4]
    umps(1:cs)=[0.05_lrk,0.1_lrk,0.10000001_lrk,1e5_lrk]
    ngycsed=2
    gycsedid(1:2)=[2,4]
    gycsedvl(1:2)=[1.7_lrk,0.4_lrk]
    np=4
    pr(1:4)=[1.2505_lrk,1.2507_lrk,1.2505001_lrk,-1._lrk]
    nd=1
    pd(1)=1.2499_lrk
    d_d(1)=0.25_lrk
    h_d(1)=0.01_lrk
    d_i(1)=0.1_lrk
    m_d(1)=5._lrk
    i_x(1)=0.07_lrk
    i_y(1)=0.1_lrk
    off_d(1)=0.035_lrk
    nmic=1
    psic(1)=1.2504_lrk
    vlmc(1)=2.2_lrk
    ixic(1)=0.003_lrk
    iyic(1)=0.004_lrk
    izic(1)=0.003_lrk
    nbrg=2
    pc(1:2)=[0.2_lrk,1.8_lrk]
    nb=3
    tpf(1:3)=[5,5,0]
    ndd(1:3)=[3._lrk,4._lrk,1._lrk]
    mu(1:3)=[123._lrk,55._lrk,0.01_lrk]
    ed(1:3)=[30._lrk,90._lrk,0._lrk]
    call predad(.false.,errmsg,ok)
    call assert_true(ok.eq.0,'PREDAD boundary control: '//trim(errmsg))
    if(ok.ne.0) call finish()
    call check_geometry()
    call analytic_integrals(truth)
    call measured_integrals(mesh)
    call vector_close(mesh,truth,1e-10_lrk,'cylindrical source integrals')
    call calccm(cm)
    refcm=(truth(2)+m_d(1)*(pd(1)+off_d(1))+vlmc(1)*psic(1))/(truth(1)+m_d(1)+vlmc(1))
    call close(cm,refcm,1e-11_lrk,'rotor CG includes disk offset')
    call indrsp(y,pr,prs,py,np,nt,9,999,errmsg,ok)
    call assert_true(ok.eq.0,'physical probe mapping succeeds')
    do i=1,3
      call close(py(i),pr(i),statol,'physical probe stays at exact input')
    enddo
    call assert_true(prs(4).eq.-1,'negative support-reference probe preserved')
    k=inddis(pd(1),errmsg,ok)
    call close(y(k),pd(1),statol,'disk station preserved near step')
    k=inddis(psic(1),errmsg,ok)
    call close(y(k),psic(1),statol,'concentrated-mass station preserved near step')
    call close(disforf(.true.),123._lrk*cos(acos(-1._lrk)/6._lrk),1e-11_lrk,'integrated distributed X force')
    call close(disforf(.false.),116.5_lrk,1e-11_lrk,'integrated distributed Z force')
    write(*,'(a,3es24.16)') 'CYLINDER mass / first moment / CG: ',mesh(1),mesh(2),cm
    call matrix_checks(truth)
  case('cone')
    cs=4
    l=2._lrk
    ps(1:cs)=[0.4_lrk,1._lrk,1.4_lrk,2._lrk]
    etype(1:cs)=[1,2,3,4]
    d(1:cs)=[0.10_lrk,0.16_lrk,0.12_lrk,0.20_lrk]
    d2(1:cs)=[0.10_lrk,0.10_lrk,0.12_lrk,0.10_lrk]
    di(1:cs)=[0._lrk,0._lrk,0.04_lrk,0.05_lrk]
    di2(1:cs)=[0._lrk,0._lrk,0.04_lrk,0.02_lrk]
    np=2
    pr(1:2)=[0.7_lrk,1.7_lrk]
    nbrg=2
    pc(1:2)=[0._lrk,2._lrk]
    kxx(1:2)=1e7_lrk
    kzz(1:2)=1e7_lrk
    cxx(1:2)=100._lrk
    czz(1:2)=100._lrk
    ngycsed=1
    gycsedid(1)=4
    gycsedvl(1)=1.6_lrk
    call analytic_integrals(truth)
    do level=1,3
      divs(1:cs)=[4,8,4,8]*2**(level-1)
      call predad(.false.,errmsg,ok)
      call assert_true(ok.eq.0,'PREDAD conical refinement: '//trim(errmsg))
      if(ok.ne.0) call finish()
      call check_geometry()
      call measured_integrals(mesh)
      err(level)=maxval(abs((mesh-truth)/truth))
      write(*,'(a,2i6,7es24.16)') 'CONE level/elements/error/M/Q/S/Id/Ip/G: ',level,nt-1,err(level),mesh
      if(level.eq.1) call matrix_checks(mesh)
      call harmonic_response(response(:,level))
      write(*,'(a,i2,8es24.16)') 'CONE_RESPONSE common probes, level ',level,response(:,level)
    enddo
    call assert_true(err(1).gt.err(2).and.err(2).gt.err(3),'cone integral error decreases on refinement')
    call assert_true(err(1)/err(2).gt.3.8_lrk.and.err(1)/err(2).lt.4.2_lrk,'cone midpoint convergence order 2: level 1/2')
    call assert_true(err(2)/err(3).gt.3.8_lrk.and.err(2)/err(3).lt.4.2_lrk,'cone midpoint convergence order 2: level 2/3')
    expected=maxval(abs(response(:,1)-response(:,2)))/maxval(abs(response(:,2)-response(:,3)))
    write(*,'(a,es24.16)') 'CONE_RESPONSE consecutive refinement-difference ratio: ',expected
    call assert_true(expected.gt.3.5_lrk.and.expected.lt.4.5_lrk,'conical response converges at unchanged physical probes')
  case('torsion','fillet_mass')
    cs=2
    l=2._lrk
    ps(1:2)=[1._lrk,2._lrk]
    d(1:2)=[0.08_lrk,0.12_lrk]
    d2=d
    divs(1:2)=[12,4]
    nbrg=2
    pc(1:2)=[0.25_lrk,0.75_lrk]
    ntfil=1
    tfilid(1)=2
    tfilrd(1)=0.006_lrk
    call predad(.true.,errmsg,ok)
    call assert_true(ok.eq.0,'PREDAD torsion control: '//trim(errmsg))
    if(ok.ne.0) call finish()
    call check_geometry()
    call analytic_integrals(truth)
    do i=1,cs
      tsum=0._lrk
      do k=1,nt-1
        if(owner((y(k)+y(k+1))/2._lrk).eq.i) tsum=tsum+tsl(k)
      enddo
      write(*,'(a,i3,2es24.16)') 'TORSION section / mapped / prescribed length: ',i,tsum,teql(i)
      call close(tsum,teql(i),1e-12_lrk,'torsion equivalent-length sum per physical section')
    enddo
    do im=1,2
      call tmatrices(im,pdm,errmsg,ok)
      call assert_true(ok.eq.0,'torsional matrix assembly')
      if(trim(scenario).eq.'fillet_mass') then
        expected=truth(5)
        write(*,'(a,i2,2es24.16)') 'TORSION model / assembled / physical polar mass: ',im,sum(tj(1:pdm,1:pdm)),expected
        call close(sum(tj(1:pdm,1:pdm)),expected,1e-10_lrk,'fillet equivalent length preserves physical polar inertia')
      endif
      call close(maxval(abs(tj(1:pdm,1:pdm)-transpose(tj(1:pdm,1:pdm)))),0._lrk,1e-12_lrk,'torsional J symmetric')
      call close(maxval(abs(tk(1:pdm,1:pdm)-transpose(tk(1:pdm,1:pdm)))),0._lrk,1e-12_lrk,'torsional K symmetric')
      if(im.eq.1) then
        k=indypf(ps(1),errmsg)
        tsum=0._lrk
        do i=1,k-1
          tsum=tsum-1._lrk/tk(i,i+1)
        enddo
        expected=g_e(1)*acos(-1._lrk)*d(1)**4/32._lrk/(ps(1)+teql(1))
        call close(1._lrk/tsum,expected,1e-10_lrk,'equivalent fillet length changes series compliance only')
      endif
    enddo
    ! Coupling property calculation is scoped by preserved physical endpoints.
    ncplg=1
    cplgid(1)=1
    cplgst(1)=1.2e6_lrk
    cplgin(1)=0.31_lrk
    cplgsr(1)=1._lrk
    cplgdp(1)=0._lrk
    do im=1,2
      call tmatrices(im,pdm,errmsg,ok)
      call assert_true(ok.eq.0,'torsional coupling resolves exact source boundaries')
      if(trim(scenario).eq.'fillet_mass') then
        expected=cplgin(1)+rho_e(2)*(ps(2)-ps(1))*acos(-1._lrk)*d(2)**4/32._lrk
        call close(sum(tj(1:pdm,1:pdm)),expected,1e-10_lrk,'coupling preserves prescribed physical inertia')
      endif
      if(im.eq.1) then
        k=indypf(ps(1),errmsg)
        tsum=0._lrk
        do i=1,k-1
          tsum=tsum-1._lrk/tk(i,i+1)
        enddo
        call close(1._lrk/tsum,cplgst(1),1e-10_lrk,'coupling preserves prescribed equivalent stiffness')
      endif
    enddo
  case('close_nodes')
    ! Distinguish a true boundary, disk, torque and probe within 1 micrometre.
    cs=2
    l=1._lrk
    ps(1:2)=[0.5_lrk,1._lrk]
    d(1:2)=[0.04_lrk,0.08_lrk]
    d2=d
    divs(1:2)=[2,2]
    np=2
    pr(1:2)=[0.5_lrk+1e-7_lrk,0.5_lrk+2e-7_lrk]
    ntbr=1
    tpc(1)=0.5_lrk+3e-7_lrk
    call predad(.false.,errmsg,ok)
    call assert_true(ok.eq.0,'PREDAD distinct close nodes')
    if(ok.ne.0) call finish()
    call check_geometry()
    call indrsp(y,pr,prs,py,np,nt,9,999,errmsg,ok)
    call assert_true(ok.eq.0,'near-boundary probes resolved')
    do i=1,np
      call close(py(i),pr(i),statol,'nearest exact probe beats first tolerance match')
    enddo
    k=indypf(tpc(1),errmsg)
    call assert_true(k.gt.0,'torsional restriction node found')
    if(k.gt.0) call close(y(k),tpc(1),statol,'torsional restriction beats first tolerance match')
  case('physical_count','near_end')
    ! c exceeds 99 after components, while the physical section count is 99.
    cs=99
    l=0.99_lrk
    do i=1,cs
      ps(i)=real(i,lrk)*0.01_lrk
    enddo
    d(1:cs)=0.04_lrk
    d2=d
    divs(1:cs)=1
    ntbr=9
    do i=1,ntbr
      tpc(i)=0.005_lrk+0.01_lrk*real(i-1,lrk)
    enddo
    ! A distinct component close to the final physical boundary must not
    ! prematurely advance legacy section metadata beyond section 99.
    if(scenario.eq.'near_end') tpc(ntbr)=l-5e-13_lrk
    call predad(.true.,errmsg,ok)
    call assert_true(ok.eq.0,'physical section count governs TEQVLEN bounds')
    if(ok.eq.0) then
      call assert_true(nt.eq.109,'all 99 boundaries and 9 restrictions retained')
      call check_geometry()
      if(scenario.eq.'near_end') then
        k=indypf(tpc(ntbr),errmsg)
        call assert_true(k.gt.0,'restriction next to final boundary found')
        if(k.gt.0) call assert_true(y(k).eq.tpc(ntbr),'near-final restriction retained exactly')
        call assert_true(y(nt).eq.ps(cs),'physical final boundary retained exactly')
        call close(sum(sdv(1:cs)),108._lrk,0._lrk,'metadata counts all mandatory intervals')
        call close(sdv(cs),2._lrk,0._lrk,'final physical section has two intervals')
        call assert_true(all(sde(1:cs).eq.d(1:cs)),'diameter metadata follows physical sections')
        call assert_true(all(sdv(cs+1:).eq.0._lrk),'metadata never advances past physical count')
      endif
    endif
  case default
    error stop 'expected boundary|cone|torsion|fillet_mass|close_nodes|physical_count|near_end'
  end select
  call finish()
contains
  subroutine reset_case()
    call foundation_reset()
    cs=0; l=0._lrk; ps=0._lrk; d=0._lrk; di=0._lrk; d2=0._lrk; di2=0._lrk
    etype=1; e=207e9_lrk; nu=0.3_lrk; rho_e=7850._lrk; divs=0; umps=0._lrk
    nd=0; pd=0._lrk; m_d=0._lrk; d_i=0._lrk; i_x=0._lrk; i_y=0._lrk
    d_d=0._lrk; h_d=0._lrk; rho_d=7850._lrk; off_d=0._lrk; dmodel=0
    nmic=0; psic=0._lrk; vlmc=0._lrk; ixic=0._lrk; iyic=0._lrk; izic=0._lrk
    np=0; pr=0._lrk; nb=0; ndd=0._lrk; mu=0._lrk; ed=0._lrk; tpf=0
    nbrg=0; pc=0._lrk; ntbr=0; tpc=0._lrk; tkk=0._lrk; tcc=0._lrk; tjj=0._lrk
    kxx=0._lrk; kxz=0._lrk; kzx=0._lrk; kzz=0._lrk
    cxx=0._lrk; cxz=0._lrk; czx=0._lrk; czz=0._lrk; bmass=0._lrk; bscale=1._lrk
    ns=0; cknd='0'; supr=' '; ngycsed=0; gycsedid=0; gycsedvl=0._lrk
    v_maior=4; v_menor=2; ld_r=0._lrk; au='D'; ntfil=0; tfilid=0; tfilrd=0._lrk; ncplg=0
  end subroutine reset_case

  integer function owner(x)
    real(lrk), intent(in) :: x
    integer :: q
    owner=0
    do q=1,cs
      if(x.le.ps(q)) then
        owner=q
        return
      endif
    enddo
  end function owner

  real(lrk) function gyro_factor(q)
    integer, intent(in) :: q
    integer :: h
    gyro_factor=1._lrk
    do h=1,ngycsed
      if(gycsedid(h).eq.q) gyro_factor=gycsedvl(h)
    enddo
  end function gyro_factor

  subroutine analytic_integrals(a)
    ! Closed polynomial antiderivatives; independent of PREDAD's Gauss audit.
    real(lrk), intent(out) :: a(6)
    real(lrk) :: ac(0:2), ic(0:4), bin2(0:2), bin4(0:4), x0, length, od, id, pio4, local_i
    integer :: q, h
    bin2=[1._lrk,2._lrk,1._lrk]; bin4=[1._lrk,4._lrk,6._lrk,4._lrk,1._lrk]
    pio4=acos(-1._lrk)/4._lrk
    a=0._lrk; x0=0._lrk
    do q=1,cs
      length=ps(q)-x0; od=d2(q)-d(q); id=di2(q)-di(q)
      do h=0,2
        ac(h)=pio4*bin2(h)*(d(q)**(2-h)*od**h-di(q)**(2-h)*id**h)
      enddo
      do h=0,4
        ic(h)=pio4/16._lrk*bin4(h)*(d(q)**(4-h)*od**h-di(q)**(4-h)*id**h)
      enddo
      do h=0,2
        a(1)=a(1)+rho_e(q)*length*ac(h)/real(h+1,lrk)
        a(2)=a(2)+rho_e(q)*length*ac(h)*(x0/real(h+1,lrk)+length/real(h+2,lrk))
        a(3)=a(3)+rho_e(q)*length*ac(h)*(x0*x0/real(h+1,lrk)+ &
          2._lrk*x0*length/real(h+2,lrk)+length*length/real(h+3,lrk))
      enddo
      local_i=0._lrk
      do h=0,4
        local_i=local_i+rho_e(q)*length*ic(h)/real(h+1,lrk)
      enddo
      a(4)=a(4)+local_i; a(5)=a(5)+2._lrk*local_i; a(6)=a(6)+2._lrk*local_i*gyro_factor(q)
      x0=ps(q)
    enddo
  end subroutine analytic_integrals

  subroutine measured_integrals(a)
    real(lrk), intent(out) :: a(6)
    real(lrk) :: dx, mass
    integer :: q
    a=0._lrk
    do q=1,nt-1
      dx=y(q+1)-y(q); mass=rs(q)*s(q)*dx
      a(1)=a(1)+mass
      a(2)=a(2)+mass*(y(q)+y(q+1))/2._lrk
      a(3)=a(3)+mass*(y(q)**2+y(q)*y(q+1)+y(q+1)**2)/3._lrk
      a(4)=a(4)+rs(q)*ie(q)*dx; a(5)=a(5)+2._lrk*rs(q)*ie(q)*dx
      a(6)=a(6)+2._lrk*rs(q)*ie(q)*dx*gfc(q)
    enddo
  end subroutine measured_integrals

  subroutine check_geometry()
    real(lrk) :: xm, x0, de, dint, frac, wanted, wantarea, wantiner, a(6), b(6), c(6)
    integer :: q, h, lastid
    do q=1,cs
      call assert_true(minval(abs(y(1:nt)-ps(q))).le.statol,'physical boundary is a mesh station')
    enddo
    do q=1,nt-1
      call assert_true(y(q+1).gt.y(q),'positive element length')
      xm=(y(q)+y(q+1))/2._lrk; h=owner(xm)
      call assert_true(h.gt.0,'element has a physical section')
      if(h.eq.0) cycle
      x0=0._lrk
      if(h.gt.1) x0=ps(h-1)
      call assert_true(y(q).ge.x0-statol.and.y(q+1).le.ps(h)+statol,'element never spans a discontinuity')
      frac=(xm-x0)/(ps(h)-x0)
      de=d(h)+(d2(h)-d(h))*frac; dint=di(h)+(di2(h)-di(h))*frac
      wantarea=acos(-1._lrk)/4._lrk*(de**2-dint**2)
      wantiner=acos(-1._lrk)/64._lrk*(de**4-dint**4)
      call close(s(q),wantarea,1e-12_lrk,'area from owning section at midpoint')
      call close(ie(q),wantiner,1e-12_lrk,'inertia from owning section at midpoint')
      call close(rs(q),rho_e(h),1e-12_lrk,'density owner')
      call close(es(q),e(h),1e-12_lrk,'Young modulus owner')
      call close(gs(q),e(h)/(2._lrk*(1._lrk+nu(h))),1e-12_lrk,'shear modulus owner')
      call close(gfc(q),gyro_factor(h),1e-12_lrk,'GYCOF owner')
      wanted=0._lrk
      do lastid=1,nb
        if(tpf(lastid).eq.5.and.nint(ndd(lastid)).eq.h) then
          wanted=mu(lastid)/(ps(h)-x0)
          call close(dfa(q),ed(lastid)*acos(-1._lrk)/180._lrk,1e-12_lrk,'distributed-force angle owner')
          exit
        endif
      enddo
      call close(dfc(q),wanted,1e-12_lrk,'distributed-force magnitude owner')
      wanted=0._lrk
      if(umps(h).gt.0.1_lrk) wanted=umps(h)
      call close(ump(q),wanted,1e-12_lrk,'UMP owner and strict cutoff')
      frac=(y(q+1)-x0)/(ps(h)-x0)
      call close(ds(q+1),d(h)+(d2(h)-d(h))*frac,1e-12_lrk,'end diameter preserves step/cone law')
      call close(di_s(q+1),di(h)+(di2(h)-di(h))*frac,1e-12_lrk,'end bore preserves step/cone law')
#ifndef ST41_BASELINE
      call assert_true(elemsec(q).eq.h,'explicit element owner')
      lastid=indsecf(q+1)
      call assert_true(lastid.eq.h,'torsion material lookup uses ending-element owner')
      rad=trextf(q+1,left,right)
      call close(rad,ds(q+1)/2._lrk,1e-12_lrk,'torsion conical outer radius')
#endif
    enddo
#ifndef ST41_BASELINE
    call analytic_integrals(a)
    call shaft_geometry_integrals(b,c)
    call vector_close(b,a,1e-12_lrk,'production exact integral vs polynomial oracle')
    call measured_integrals(a)
    call vector_close(c,a,1e-12_lrk,'production FE integral vs independent accumulation')
#endif
    write(*,'(a,i0,a,i0)') 'MESH: physical sections=',cs,' elements=',nt-1
  end subroutine check_geometry

  subroutine matrix_checks(a)
    real(lrk), intent(in) :: a(6)
    real(lrk) :: vx(500), vz(500), rx(500), rz(500), expected_mass, expected_first, expected_g, defect
    real(lrk) :: symm, symk, skg, scale, omega
    complex(wp), allocatable :: hh(:,:)
    integer :: q, pp0, dmm, oki, saved_nbrg
    ! Zero bearings for conservative rigid-field checks; stations are retained.
    saved_nbrg=nbrg; nbrg=0
    call matrizes(pp0,dmm,errmsg,oki)
    call assert_true(oki.eq.0,'native lateral assembly')
    if(oki.ne.0) then
      nbrg=saved_nbrg
      return
    endif
    symm=maxval(abs(mm(1:dm,1:dm)-transpose(mm(1:dm,1:dm))))/maxval(abs(mm(1:dm,1:dm)))
    symk=maxval(abs(mkb(1:dm,1:dm)-transpose(mkb(1:dm,1:dm))))/maxval(abs(mkb(1:dm,1:dm)))
    skg=maxval(abs(mg(1:dm,1:dm)+transpose(mg(1:dm,1:dm))))/maxval(abs(mg(1:dm,1:dm)))
    call close(symm,0._lrk,1e-13_lrk,'M symmetry')
    call close(symk,0._lrk,1e-13_lrk,'structural K symmetry')
    call close(skg,0._lrk,1e-13_lrk,'G skew symmetry')
    vx=0._lrk; vz=0._lrk; rx=0._lrk; rz=0._lrk
    do q=1,nt
      vx(4*q-3)=1._lrk; vz(4*q-2)=1._lrk
      rx(4*q-3)=y(q); rx(4*q)=-1._lrk
      rz(4*q-2)=y(q); rz(4*q-1)=1._lrk
    enddo
    expected_mass=a(1)+sum(md(1:nd))+sum(vlmc(1:nmic))
    expected_first=a(2)+sum(md(1:nd)*(pd(1:nd)+off_d(1:nd)))+sum(vlmc(1:nmic)*psic(1:nmic))
    expected_g=a(6)+sum(idy(1:nd))+sum(iyic(1:nmic))
    call close(dot_product(vx(1:dm),matmul(mm(1:dm,1:dm),vx(1:dm))),expected_mass,1e-10_lrk,'M rigid X mass')
    call close(dot_product(vz(1:dm),matmul(mm(1:dm,1:dm),vz(1:dm))),expected_mass,1e-10_lrk,'M rigid Z mass')
    call close(dot_product(vx(1:dm),matmul(mm(1:dm,1:dm),rx(1:dm))),expected_first,1e-10_lrk,'M first moment and disk offset')
    call close(dot_product(rx(1:dm),matmul(mg(1:dm,1:dm),rz(1:dm))),-expected_g,1e-10_lrk,'G rigid rotations polar coefficient')
    scale=maxval(abs(mkb(1:dm,1:dm)))
    defect=maxval(abs(matmul(mkb(1:dm,1:dm),rx(1:dm))))/(scale*maxval(abs(rx(1:dm))))
    call close(defect,0._lrk,1e-12_lrk,'K rigid rotation null field')
    allocate(hh(1000,1000))
    do q=1,2
      omega=17._lrk*real(q,lrk)
      hh=cmplx(0._wp,0._wp,wp)
      call mntmth(omega,dmm,pp0,0,hh,errmsg,oki)
      call assert_true(oki.eq.0,'augmented assembly at selected speed: '//trim(errmsg))
      defect=maxval(abs(aimag(hh(1:dm,1:dm))/omega-omega*mg(1:dm,1:dm)))
      defect=defect/max(1._lrk,maxval(abs(omega*mg(1:dm,1:dm))))
      call close(defect,0._lrk,1e-12_lrk,'Omega G coefficient stays linear in augmented kernel')
    enddo
    deallocate(hh)
    write(*,'(a,4es16.8)') 'ASSEMBLY M/K/G defects / final OmegaG defect: ',symm,symk,skg,defect
    nbrg=saved_nbrg
  end subroutine matrix_checks

  subroutine harmonic_response(qout)
    ! Production augmented 2n solve at 30 Hz; meshes share exact probe sites.
    ! Physical residual is independently reconstructed after solving.
    complex(wp), intent(out) :: qout(4)
    complex(wp), allocatable :: h(:,:), lu(:,:), rhs(:), force(:), z(:,:), r(:)
    integer, allocatable :: piv(:)
    integer :: p0, ndof, st, probe, q, aidx
    real(lrk) :: omega, res, kin, denom
    qout=cmplx(0._wp,0._wp,wp)
    omega=60._lrk*acos(-1._lrk)
    call matrizes(p0,ndof,errmsg,st)
    call assert_true(st.eq.0,'response mesh assembly')
    if(st.ne.0) return
    allocate(h(1000,1000),lu(1000,1000),rhs(1000),force(1000),piv(1000),z(dm,dm),r(dm))
    h=cmplx(0._wp,0._wp,wp); force=cmplx(0._wp,0._wp,wp)
    call mntmth(omega,ndof,p0,0,h,errmsg,st)
    call assert_true(st.eq.0,'response augmented matrix')
    probe=inddis(pr(1),errmsg,st)
    force(4*probe-3)=cmplx(1._wp,0._wp,wp)
    force(4*probe-2)=cmplx(0._wp,-0.3_wp,wp)
    lu=h; rhs=force
    call zgetrf(ndof,ndof,lu,1000,piv,st)
    call assert_true(st.eq.0,'response ZGETRF INFO')
    if(st.eq.0) then
      call zgetrs('N',ndof,1,lu,1000,piv,rhs,1000,st)
      call assert_true(st.eq.0,'response ZGETRS INFO')
      z=h(1:dm,1:dm)-omega**2*mm(1:dm,1:dm)
      r=matmul(z,rhs(1:dm))-force(1:dm)
      denom=maxval(sum(abs(z),dim=2))*maxval(abs(rhs(1:dm)))+maxval(abs(force(1:dm)))
      res=maxval(abs(r))/denom
      kin=maxval(abs(rhs(dm+1:2*dm)-cmplx(0._wp,omega,wp)*rhs(1:dm)))/maxval(abs(rhs(dm+1:2*dm)))
      call close(res,0._lrk,1e-10_lrk,'physical response residual')
      call close(kin,0._lrk,1e-10_lrk,'augmented response kinematics')
      do q=1,2
        probe=inddis(pr(q),errmsg,st)
        aidx=4*probe-3
        qout(2*q-1:2*q)=rhs(aidx:aidx+1)
      enddo
      write(*,'(a,2es24.16)') 'RESPONSE physical residual / kinematic error: ',res,kin
    endif
    deallocate(h,lu,rhs,force,piv,z,r)
  end subroutine harmonic_response

  subroutine compare_response_logs()
    character(len=1024) :: current_path, reference_path, line
    character(len=*), parameter :: prefix='CONE_RESPONSE common probes, level'
    complex(wp) :: value(4,3,2)
    logical :: present(3,2)
    real(wp) :: parts(8), difference, tolerance, worst, largest
    integer :: file, unit, status, lev, q
    call get_command_argument(2,current_path)
    call get_command_argument(3,reference_path)
    present=.false.; value=cmplx(0._wp,0._wp,wp)
    do file=1,2
      if(file.eq.1) then
        open(newunit=unit,file=trim(current_path),status='old',action='read',iostat=status)
      else
        open(newunit=unit,file=trim(reference_path),status='old',action='read',iostat=status)
      endif
      call assert_true(status.eq.0,'response comparison log is available')
      if(status.ne.0) return
      do
        read(unit,'(a)',iostat=status) line
        if(status.ne.0) exit
        if(index(line,prefix).ne.1) cycle
        read(line(len(prefix)+1:),*,iostat=status) lev,parts
        call assert_true(status.eq.0,'response comparison record parses')
        if(status.ne.0.or.lev.lt.1.or.lev.gt.3) cycle
        do q=1,4
          value(q,lev,file)=cmplx(parts(2*q-1),parts(2*q),wp)
        enddo
        present(lev,file)=.true.
      enddo
      close(unit)
    enddo
    call assert_true(all(present),'all three common meshes recorded in both logs')
    worst=0._wp; largest=0._wp
    do lev=1,3
      do q=1,4
        difference=abs(value(q,lev,1)-value(q,lev,2))
        tolerance=1e-12_wp+1e-6_wp*max(abs(value(q,lev,1)),abs(value(q,lev,2)))
        call assert_true(difference.le.tolerance,'common-mesh displacement phasor acceptance')
        largest=max(largest,difference); worst=max(worst,difference/tolerance)
      enddo
    enddo
    write(*,'(a,2es24.16)') 'COMMON_MESH maximum absolute delta / acceptance ratio: ',largest,worst
  end subroutine compare_response_logs

  subroutine close(actual,wanted,tol,label)
    real(lrk), intent(in) :: actual,wanted,tol
    character(len=*), intent(in) :: label
    logical :: pass
    if(wanted.eq.0._lrk) then
      pass=abs(actual).le.tol
    else
      pass=abs(actual-wanted).le.tol*abs(wanted)
    endif
    call assert_true(pass,label)
    if(.not.pass) write(*,'(a,3es24.16)') '  actual / expected / difference: ',actual,wanted,actual-wanted
  end subroutine close

  subroutine vector_close(actual,wanted,tol,label)
    real(lrk), intent(in) :: actual(:),wanted(:),tol
    character(len=*), intent(in) :: label
    integer :: q
    do q=1,size(actual)
      call close(actual(q),wanted(q),tol,label)
    enddo
  end subroutine vector_close

  subroutine assert_true(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    checks=checks+1
    if(.not.condition) then
      failures=failures+1
      write(*,'(a)') 'FAIL: '//trim(label)
    endif
  end subroutine assert_true

  subroutine finish()
    write(*,'(a,a,a,i0,a,i0)') 'GEOMETRY ',trim(scenario),': checks=',checks,' failures=',failures
    if(failures.gt.0) stop 1
    stop 0
  end subroutine finish
end program geometry_regression
