program p1_poles
  use rd_kinds, only: wp
  use rd_modal_metrics, only: spectrum_report,prescribed_metrics,modal_metrics_t
  use rd_modal_metrics, only: record_generalized_roots
  use rd_spectral_families, only: spectral_metric,spectral_point,spectral_initialize_metric,spectral_solve
#ifdef ST41_P1
  use rd_modal_metrics, only: conservative_reference_report,eigen_backward_error,eigen_abs_error,eigen_evidence_ready
  use rd_modal_metrics, only: record_schur_evidence
#endif
  implicit none
  complex(wp) :: aa(4,4),bb(4,4),fi(4,4),psi(4,4),a(4),k(2,2),d(2,2),beta(4)
  real(wp) :: mass(2,2),w1,w2,g1,g2,expected(4),observed(4),tmp
  integer :: ok,j,l
  character(len=32) :: name,driver
  character(len=99) :: errmsg
  type(modal_metrics_t) :: metrics
  type(spectral_metric) :: metric
  type(spectral_point) :: point

  call get_command_argument(1,name)
  call get_command_argument(2,driver)
  if(len_trim(driver)==0)driver='pencil'
  aa=cmplx(0._wp,0._wp,wp);bb=aa;k=cmplx(0._wp,0._wp,wp);d=k;mass=0._wp
  mass(1,1)=2._wp;mass(2,2)=3._wp;k(1,1)=8._wp;k(2,2)=27._wp
  g1=0._wp;g2=0._wp;w1=2._wp;w2=3._wp
  select case(trim(name))
  case('free')
    k(1,1)=1.e8_wp;k(1,2)=-1.e8_wp;k(2,1)=-1.e8_wp;k(2,2)=1.e8_wp
  case('stable','unstable','weak_unstable')
    g1=-0.1_wp;g2=-0.2_wp
    if(trim(name)=='unstable')g1=0.1_wp
    if(trim(name)=='weak_unstable')g1=1.e-12_wp
    d(1,1)=-2._wp*g1*mass(1,1);d(2,2)=-2._wp*g2*mass(2,2)
  case('soft_unstable')
    k(1,1)=-2.e-24_wp
  case default
    error stop 'usage: p1_poles free|stable|unstable|weak_unstable|soft_unstable'
  end select
  aa(1:2,1:2)=d
  aa(1:2,3:4)=cmplx(mass,0._wp,wp);aa(3:4,1:2)=cmplx(mass,0._wp,wp)
  bb(1:2,1:2)=k;bb(3:4,3:4)=-cmplx(mass,0._wp,wp)
  if(driver=='pencil')then
    call adjeig(aa,bb,fi,psi,a,4,4,4,.false.,errmsg,ok)
  else if(driver=='schur')then
    call spectral_initialize_metric(mass,3._wp,metric,errmsg,ok)
    if(ok/=0)error stop 'spectral mass metric failed'
    call spectral_solve(metric,k,d,0._wp,point,errmsg,ok)
    a=-point%poles;beta=cmplx(1._wp,0._wp,wp)
    call record_generalized_roots(a,beta,[1,2,3,4],4)
#ifdef ST41_P1
    call record_schur_evidence(point%operator,point%schur,point%vectors,point%poles,metric%omega_ref,ok)
#endif
  else
    error stop 'unknown eigensolver driver'
  endif
  if(ok/=0)then
    write(*,'(a)') trim(errmsg)
    error stop 'physical pencil solve failed'
  endif
#ifdef ST41_P1
  call conservative_reference_report(trim(name),0._wp,mass,k,d)
  if(.not.all(eigen_evidence_ready))error stop 'root evidence missing'
  if(maxval(eigen_backward_error)>1.e-10_wp)error stop 'eigenproblem backward residual too large'
  write(*,'(a,es24.16)') 'MAX_BACKWARD_ERROR ',maxval(eigen_backward_error)
#endif
  call spectrum_report(trim(name),0._wp,a)
  do j=1,4
    metrics=prescribed_metrics(a(j))
    write(*,'(a,i0,4es24.16)') 'RAW_POLE ',j,-real(a(j),wp),-aimag(a(j)),metrics%wd,metrics%delta
    if(metrics%delta_defined)then
      if(abs(metrics%delta+2._wp*acos(-1._wp)*metrics%growth/metrics%wd)>1.e-14_wp) &
        error stop 'decrement identity changed'
    endif
  enddo
  if(trim(name)=='stable'.or.trim(name)=='unstable'.or.trim(name)=='weak_unstable')then
    expected=[sqrt(w1*w1-g1*g1),sqrt(w1*w1-g1*g1),sqrt(w2*w2-g2*g2),sqrt(w2*w2-g2*g2)]
    observed=abs(aimag(a))
    do j=2,4
      tmp=observed(j);l=j-1
      do while(l>=1)
        if(observed(l)<=tmp)exit
        observed(l+1)=observed(l);l=l-1
      enddo
      observed(l+1)=tmp
    enddo
    if(trim(name)/='weak_unstable')then
      if(maxval(abs(observed-expected))>1.e-12_wp)error stop 'independent oscillator frequency mismatch'
      if(abs(maxval(-real(a,wp))-max(g1,g2))>1.e-14_wp)error stop 'independent oscillator growth mismatch'
    else
      ! Characterize a deliberately underresolved problem; the audit must
      ! expose uncertainty rather than certify this physically unstable model.
      write(*,'(a,2es24.16)') 'WEAK_ORACLE_ERRORS ',maxval(abs(observed-expected)), &
        abs(maxval(-real(a,wp))-max(g1,g2))
#ifdef ST41_P1
      if(maxval(abs(observed-expected))>maxval(eigen_abs_error)+1.e-12_wp) &
        error stop 'reported resolution does not cover the weak-mode oracle error'
#endif
    endif
  endif
  if(trim(name)=='soft_unstable')then
    if(abs(maxval(-real(a,wp))-1.e-12_wp)>1.e-24_wp) &
      error stop 'resolved soft unstable root lost'
  endif
  write(*,'(a,a,1x,a)') 'P1_POLES_NATIVE PASS ',trim(name),trim(driver)
end program p1_poles
