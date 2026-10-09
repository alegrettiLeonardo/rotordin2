program messages_cases
  use rd_textfun, only: fmtmsgf, fopmsf, fomsgf, fwmsgf, femsgf, fhmsgf
  implicit none
  character(len=32) :: mode
  character(len=512) :: longtext, result
  character(len=128) :: expected128
  character(len=99) :: expected99
  integer :: checks

  checks = 0
  longtext = repeat('x',len(longtext))
  call get_command_argument(1,mode)
  select case (trim(mode))
  case ('long_optional')
    result = fmtmsgf(99,'entrada','error reading(SECTIONS)',longtext,1)
    call expect(result(1:34),'entrada->error reading(SECTIONS) <','long optional origin')
  case ('long_section')
    result = fopmsf(99,'entrada',3,longtext,'bad.txt')
    call expect(result(1:23),'entrada->error reading(','long section origin')
  case ('short')
    call short_cases()
  case ('all')
    call short_cases()
    result = fmtmsgf(512,'entrada','error reading(SECTIONS)',longtext,1)
    call expect(result(1:34),'entrada->error reading(SECTIONS) <','long option origin')
    if (len_trim(result) /= 128) error stop 'fixed fmtmsgf capacity changed'
    result = fmtmsgf(512,'','',longtext,1)
    call expect(result(1:7),'no msg<','empty message with long option')
    result = fmtmsgf(512,'',longtext,'',0)
    call expect(result(1:128),longtext(1:128),'long unprefixed message')
    result = fmtmsgf(512,longtext,'error reading','',0)
    call expect(result(1:128),longtext(1:128),'long module')
    result = fopmsf(99,'entrada',3,longtext,longtext)
    call expect(result(1:23),'entrada->error reading(','long section and path origin')
    call expect(fmtmsgf(0,'entrada','error reading',longtext,1),'','empty result')
    call expect(fmtmsgf(1,'entrada','error reading',longtext,1),'e','one character result')
    call expect(fmtmsgf(17,'entrada','error reading',longtext,1),'entrada->error re','limited result')
    call expect(fopmsf(0,'entrada',3,longtext,longtext),'','empty file-error result')
    call expect(fopmsf(15,'entrada',3,longtext,longtext),'entrada->error ','limited file-error result')
    result = fomsgf(99,'entrada',3,longtext,1)
    call expect(result(1:22),'entrada->error reading','error wrapper')
    result = fwmsgf(99,'entrada',3,longtext,1)
    call expect(result(1:9),'entrada->','warning wrapper')
    result = femsgf(99,'entrada',3,3,1)
    call expect(result(1:22),'entrada->error reading','combined wrapper')
    expected99 = fhmsgf(99,'entrada',1,longtext,1)
    result = fhmsgf(512,'entrada',1,longtext,1)
    call expect(result(1:99),expected99,'long help result retains prefix')
    call expect(fhmsgf(0,'entrada',1,longtext,1),'','empty help result')
    expected128 = fmtmsgf(128,'entrada','error reading',longtext,0)
    call expect(expected128(1:23),'entrada->error reading ','plain long optional origin')
  case default
    error stop 'usage: messages_cases short|all|long_optional|long_section'
  end select
  write(*,'(a,a,a,i0)') 'MESSAGES_CASES PASS mode=',trim(mode),' checks=',checks
contains
  subroutine short_cases()
    call expect(fmtmsgf(99,'entrada','error reading(SECTIONS)','bad.txt',1), &
      'entrada->error reading(SECTIONS) <bad.txt>','short formatted error')
    call expect(fopmsf(99,'entrada',3,'SECTIONS','bad.txt'), &
      'entrada->error reading(SECTIONS) <bad.txt>','short file error')
    call expect(fmtmsgf(99,'','','',0),'no msg','all blank')
    call expect(fmtmsgf(99,'entrada','','bad.txt',1), &
      'entrada->no msg <bad.txt>','empty message')
    call expect(fmtmsgf(99,'','error reading','bad.txt',1), &
      'error reading<bad.txt>','no-module historical spacing')
    call expect(fopmsf(99,'entrada',3,'',''), &
      'entrada->error reading','no section or file')
  end subroutine short_cases

  subroutine expect(actual,expected,label)
    character(len=*), intent(in) :: actual, expected, label
    checks = checks+1
    if (actual /= expected) then
      write(*,'(a)') 'FAIL '//label
      write(*,'(a)') 'actual: ['//actual//']'
      write(*,'(a)') 'expected: ['//expected//']'
      error stop 1
    end if
  end subroutine expect
end program messages_cases
