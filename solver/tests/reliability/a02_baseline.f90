! Reproduce the actual original recovery path before applying A02.
program a02_baseline
  use rd_kinds, only: wp
  use com_sec, only: nt,y
  use com_sea, only: ie
  use com_sed, only: ds
  use com_sprat, only: crat
  use com_sprat2, only: gsst
  use com_eqvlen, only: tsl
  implicit none
  complex(wp) :: theta(2)
  real(wp) :: rd(2),delta,torque,stress
  nt=2; y(1:2)=[0._wp,1._wp]
  ie(1)=5.e-7_wp; ds(1:2)=2*(2.e-6_wp/acos(-1._wp))**.25_wp
  crat(1)=1._wp; gsst(1)=1.e11_wp; tsl(1)=0._wp
  theta=[cmplx(0.001_wp,0._wp,wp),cmplx(-0.001_wp,0._wp,wp)]
  ! This is the conversion in baseline tresp_f, followed by real native recovery.
  rd=abs(theta)
  call tdvtrst(1,1,2,rd,delta,torque,stress)
  write(*,'(a,es24.16)') 'OLD_ACTUAL_TORQUE_NM=',torque
  write(*,'(a,es24.16)') 'ANALYTIC_EXPECTED_AMPLITUDE_NM=',200._wp
  if (abs(torque)<1.e-14_wp) then
    write(*,'(a)') 'BASELINE_PHASE_COUNTEREXAMPLE FAIL_REPRODUCED'
  else
    error stop 'Baseline defect not reproduced; inspect exact baseline source.'
  end if
end program
