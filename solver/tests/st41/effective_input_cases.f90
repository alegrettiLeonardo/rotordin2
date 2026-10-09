program effective_input_cases
  use rd_kinds, only: lrk,wp
  use com_cpbn, only: spdn
  use com_cpb, only: nini,nfin
  use com_mfa, only: rm
  use com_inaudit, only: active_analysis
  use com_ymc, only: pc,nbrg
  use com_man, only: sc
  use com_knd, only: cknd,supr
  use com_fndctl, only: factive
  use com_nbc, only: cp
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  implicit none
  real(lrk) :: speed,expspdf
  character(len=32) :: source
  complex(wp) :: matrix(2,2)
  integer :: model_rank2
  integer :: assertions=0,count,ok,nbr,iu,ios
  real(lrk) :: scale,static_flag,static_stiffness,par(9,10),rad
  character(len=99) :: errmsg
  character(len=256) :: line
  nini=1000._lrk; nfin=5000._lrk; rm=0._lrk; spdn=1800._lrk
  call expspd_resolve(speed,source)
  call check(speed==1800._lrk.and.source=='NRAT','NRAT precedence')
  call check(expspdf()==speed,'original export interface NRAT')
  spdn=0._lrk; rm=1200._lrk
  call expspd_resolve(speed,source)
  call check(speed==1200._lrk.and.source=='MDRPM','MDRPM precedence')
  call check(expspdf()==speed,'original export interface MDRPM')
  rm=0._lrk
  call expspd_resolve(speed,source)
  call check(speed==3000._lrk.and.source=='CAMPBELL_MIDPOINT','Campbell fallback')
  call check(expspdf()==speed.and.rm==0._lrk,'zero MDRPM retained')
  matrix=cmplx(0._wp,0._wp,wp)
  call check(model_rank2(matrix)==0,'zero coupling')
  matrix(1,2)=cmplx(1._wp,0._wp,wp)
  call check(model_rank2(matrix)==1,'cross-only partial coupling')
  matrix(2,1)=cmplx(-2._wp,0._wp,wp)
  call check(model_rank2(matrix)==2,'nonreciprocal full crossed coupling')
  matrix=matrix*1.e-100_wp
  call check(model_rank2(matrix)==2,'rank is scale independent')
  matrix=cmplx(0._wp,0._wp,wp)
  matrix(1,1)=1; matrix(2,2)=1
  matrix(1,2)=cmplx(0._wp,1._wp,wp); matrix(2,1)=cmplx(0._wp,-1._wp,wp)
  call check(model_rank2(matrix)==1,'K+i omega C cancellation is partial, not absent topology')
  call input_count_scale('2',count,scale,errmsg,ok)
  call check(ok==0.and.count==2.and.scale==1._lrk,'absent TABLE scale retains default')
  call input_count_scale('2 2.5',count,scale,errmsg,ok)
  call check(ok==0.and.count==2.and.scale==2.5_lrk,'complete TABLE scale is retained')
  call input_count_scale('2 INVALID',count,scale,errmsg,ok)
  call check(ok<0,'malformed present TABLE scale rejected')
  call input_count_scale('2 NaN',count,scale,errmsg,ok)
  call check(ok<0,'nonfinite TABLE scale rejected before comparison')
  call input_count_scale('2 Infinity',count,scale,errmsg,ok)
  call check(ok<0,'infinite TABLE scale rejected')
  call input_count_scale('2 0',count,scale,errmsg,ok)
  call check(ok<0,'zero TABLE scale rejected')
  call input_count_scale('',count,scale,errmsg,ok)
  call check(ok<0,'missing required count rejected')
  call input_bearing_header('2',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok==0.and.count==2.and.scale==1._lrk.and.static_flag==0._lrk.and. &
    static_stiffness==5.e20_lrk,'BEARING all absent optional defaults')
  call input_bearing_header('2 3',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok==0.and.scale==3._lrk.and.static_flag==0._lrk.and.static_stiffness==5.e20_lrk, &
    'BEARING one optional field')
  call input_bearing_header('2 3 1',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok==0.and.scale==3._lrk.and.static_flag==1._lrk.and.static_stiffness==5.e20_lrk, &
    'BEARING two optional fields')
  call input_bearing_header('2 3 1 7e8',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok==0.and.scale==3._lrk.and.static_flag==1._lrk.and.static_stiffness==7.e8_lrk, &
    'BEARING complete static fields')
  call input_bearing_header('2 0',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok==0.and.scale==0._lrk,'zero global scale remains explicit')
  call input_bearing_header('2 -1',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok==0.and.scale==-1._lrk,'signed global scale preserved')
  call input_bearing_header('2 INVALID',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok<0,'malformed present BEARING scale rejected')
  call input_bearing_header('2 1 INVALID',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok<0,'malformed present RKS rejected')
  call input_bearing_header('2 1 0 INVALID',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok<0,'malformed present FXSTF rejected')
  call input_bearing_header('2 NaN',count,scale,static_flag,static_stiffness,errmsg,ok)
  call check(ok<0,'nonfinite BEARING field rejected')

  nbrg=1; cp=1; cknd='0'
  rad=ieee_value(1._lrk,ieee_quiet_nan)
  call parman(rad,.false.,9,nbr,par,errmsg,ok)
  call check(ok<0,'PARMAN rejects NaN before ordered comparison')
  call parmant(rad,par,nbr,errmsg,ok)
  call check(ok<0,'PARMANT rejects NaN before ordered comparison')
  call parmant(huge(rad),par,nbr,errmsg,ok)
  call check(ok<0,'TABLE rejects unrepresentable rpm before multiplication')

! A diagnostic must not introduce overflow for otherwise finite K/C or speed.
  active_analysis='FREQUENCY_RESPONSE'; pc=0._lrk; sc=1._lrk
  supr=' '; factive=.false.; par=0._lrk
  par(1,[1,4,5,8])=1.e308_lrk
  open(newunit=iu,status='scratch',action='readwrite')
  call model_effective_bearing_unit(iu,1.e307_lrk,.false.,9,1,par)
  rewind(iu)
  read(iu,'(a)') line
  read(line(index(line,'RPM=')+4:),*,iostat=ios) speed
  call check(ios==0,'large finite diagnostic rpm is readable')
  call check(abs(speed/1.e307_lrk-30._lrk/acos(-1._lrk))<1.e-14_lrk, &
    'large finite diagnostic conversion has no intermediate overflow')
  close(iu)
  open(newunit=iu,status='scratch',action='readwrite')
  call model_effective_bearing_unit(iu,huge(rad),.false.,9,1,par)
  rewind(iu); read(iu,'(a)') line
  call check(index(line,'OUT_OF_REPRESENTABLE_RANGE')>0,'unrepresentable diagnostic rpm is explicit')
  close(iu)
  print '(a,i0,a)', 'PASS IN-01/02: ',assertions,' export/rank/header/finite diagnostic assertions'
contains
  subroutine check(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    assertions=assertions+1
    if(.not.condition) then
      print '(a,a)', 'FAIL ',label
      stop 1
    endif
  end subroutine
end program
