! Exercise the public legacy vector route with actual production assembly,
! eigensolves, association, root refinement and publication. No math stubs.
program p1_vectors
  use rd_kinds, only: wp,lrk
  use rd_campbell_engine, only: run_campbell_vectors
  use com_mat, only: dm,mm,mg
  use com_mtk, only: mk1
  use com_cpb, only: nini,nfin,dw,npi,ncc,imt
  use com_cpbd, only: dmp,nit
  use com_cpbn, only: spdn
  use com_ymc, only: nbrg
  use com_knd, only: cknd,supr
  implicit none
  character(len=32)::arg
  character(len=99)::errmsg
  integer::ok,count,display
  call get_command_argument(1,arg);read(arg,*)count
  display=50
  if(command_argument_count()>1)then
    call get_command_argument(2,arg);read(arg,*)display
  endif
  call foundation_reset()
  dm=2;mm=0._lrk;mg=0._lrk;mk1=0._lrk
  mm(1,1)=1._lrk;mm(2,2)=2._lrk
  mk1(1,1)=4._lrk;mk1(2,2)=18._lrk
  mg(1,2)=0.15_lrk;mg(2,1)=-mg(1,2)
  nbrg=0;cknd='0';supr=' '
  nini=0._lrk;nfin=60._lrk;dw=real(count,lrk)
  npi=display;ncc=2;imt=1;nit=1;dmp=0._lrk;dmp(1)=1._lrk;spdn=0._lrk
  call run_campbell_vectors(0,.false.,.true.,.false.,errmsg,ok)
  if(ok/=0)then
    write(*,'(a)')trim(errmsg)
    error stop 'native vector Campbell failed'
  endif
  write(*,'(a,2i6)') 'P1_VECTORS_NATIVE PASS ',count,display
end program p1_vectors
