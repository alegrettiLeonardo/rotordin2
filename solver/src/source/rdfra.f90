!     $Id$
!     ==================================================================
!
!>    @file rdfra.f
!>    @brief unbalance response analysis, last changes:<br>
!>    new analise resposta desbalaceamento - francisco - 03/12/2008<br>
!>    changed maxamp, ld=0 dentro loop pontos - francisco - 26/02/2010<b
!>    changed getbds, verificacao de limite - francisco - 16/06/2011<br>
!>    add st em getbds, fatamo e maxamp - francisco - 16/06/2011<br>
!>    removed ma argument and af check on maxamp - francisco - oct-15<br
!>    added ok, errmsg arguments on maxamp - francisco - oct-15<br>
!>    added central messages - francisco - francisco - apr-19<br>
!>    updated quad, call qcfr from matfun - franciso - mar-21<br>
!>    removed mxint, updated call to mxqr on matfun - francisco - mar-21
!>    added precision on maxamp, changed name to fatamof - francisco - o
!
!     ==================================================================
!>    @brief linear interpolation for amplitude and speed.
!
!>    @param[in] ix speed and aplitude x position index
!>    @param[in] iy speed and aplitude y position index
!>    @param[in] ip number of the desired position
!>    @param[in] y y value to get the interpolated x value
!>    @param[in] rpg speed vector rpm
!>    @param[in] amp complex amplitude matrix
!>    @param[in] mxp position, first dimension of amplitude matrix
!>    @param[in] mte speed, second dimension of amplitude matrix
!>    @return linear interpolated values
!
real(lrk) function linintx(ix,iy,ip,y,rpg,amp,mxp,mte)
  use rd_kinds, only: lrk, wp
  implicit none
!
!     arguments
  integer :: ix, iy, ip, mxp, mte
  real(lrk) :: y
  real(lrk) :: rpg(mte)
  complex(wp) :: amp(mxp,mte)
!
!     locals
  real(lrk) :: a, b
  logical :: found, valid
!
  intrinsic :: abs, real
!
!     Compatibility entry point. The AF path consumes explicit success
!     from af_interp instead of interpreting this scalar as a sentinel.
  linintx = 0._lrk
  if (ix .lt. 1 .or. ix .gt. mte .or. iy .lt. 1 .or. iy .gt. mte) return
  if (ip .lt. 1 .or. ip .gt. mxp) return
  call af_magnitude(amp(ip,ix),a,valid)
  if (.not. valid) return
  call af_magnitude(amp(ip,iy),b,valid)
  if (.not. valid) return
  call af_interp(y,rpg(ix),a,rpg(iy),b,linintx,found)
!
  return
!
end function linintx
!
!     ==================================================================
!>    @brief get the x value for a given y with a starting point,
!>      x is the speed and y the amplitude.
!
!>    @param[in] ym value for the required amplitude
!>    @param[in] ix speed and aplitude x position index
!>    @param[in] ip number of the desired position
!>    @param[in] lf search direction 1=left, -1=right
!>    @param[in] rpg speed vector rpm
!>    @param[in] amp complex amplitude matrix
!>    @param[in] np number of output points
!>    @param[in] mxp position, first dimension of amplitude matrix
!>    @param[in] mte speed, second dimension of amplitude matrix
!>    @return x value for the given y
!
real(lrk) function getbds(ym,ix,ip,lf,rpg,amp,np,mxp,mte)
  use rd_kinds, only: lrk, wp
  implicit none
!
!     arguments
  integer :: mxp, mte, ix, ip, lf, np
  real(lrk) :: ym
  real(lrk) :: rpg(mte)
  complex(wp) :: amp(mxp,mte)
!
!     locals
  logical :: found
!
!     Retain the historical external signature for scalar callers.
!     fatamof uses getbds_checked and its separate success flag.
  call getbds_checked(ym,ix,ip,lf,rpg,amp,np,mxp,mte,getbds,found)
!
  return
!
end function getbds
!
!     ==================================================================
!>    @brief Magnitude guarded against nonfinite or overflowing input.
subroutine af_magnitude(z,a,valid)
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use rd_kinds, only: lrk, wp
  implicit none
  complex(wp), intent(in) :: z
  real(lrk), intent(out) :: a
  logical, intent(out) :: valid
  real(lrk) :: scale, factor, zr, zi

  valid = .false.
  a = 0._lrk
  zr = real(z,lrk)
  zi = aimag(z)
  if (.not. ieee_is_finite(zr) .or. .not. ieee_is_finite(zi)) return
  scale = max(abs(zr),abs(zi))
  if (scale .gt. 0._lrk) then
    factor = sqrt((zr/scale)**2+(zi/scale)**2)
    if (scale .gt. huge(a)/factor) return
    a = scale*factor
  end if
  valid = .true.
end subroutine af_magnitude
!
!     ==================================================================
!>    @brief Validate finite amplitudes and a strictly increasing grid.
logical function af_curve_valid(ip,rpg,amp,np,mxp,mte)
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use rd_kinds, only: lrk, wp
  implicit none
  integer, intent(in) :: ip, np, mxp, mte
  real(lrk), intent(in) :: rpg(mte)
  complex(wp), intent(in) :: amp(mxp,mte)
  integer :: j
  real(lrk) :: a
  logical :: valid

  af_curve_valid = .false.
  if (np .lt. 1 .or. np .gt. mte .or. ip .lt. 1 .or. ip .gt. mxp) return
  do j = 1,np
    if (.not. ieee_is_finite(rpg(j))) return
    call af_magnitude(amp(ip,j),a,valid)
    if (.not. valid) return
    if (j .gt. 1) then
      if (rpg(j) .le. rpg(j-1)) return
!       Ensure that the interval is representable even on a signed grid.
      if (rpg(j-1) .lt. 0._lrk) then
        if (rpg(j) .gt. huge(a)+rpg(j-1)) return
      end if
    end if
  end do
  af_curve_valid = .true.
end function af_curve_valid
!
!     ==================================================================
!>    @brief Bounded linear crossing, including equality at either end.
subroutine af_interp(y,x1,a1,x2,a2,x,found)
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use rd_kinds, only: lrk
  implicit none
  real(lrk), intent(in) :: y, x1, a1, x2, a2
  real(lrk), intent(out) :: x
  logical, intent(out) :: found
  real(lrk) :: t

  x = 0._lrk
  found = .false.
  if (.not. ieee_is_finite(y) .or. .not. ieee_is_finite(x1) .or. .not. ieee_is_finite(x2)) return
  if (.not. ieee_is_finite(a1) .or. .not. ieee_is_finite(a2)) return
  if (a1 .lt. 0._lrk .or. a2 .lt. 0._lrk .or. x1 .eq. x2) return
  if (y .lt. min(a1,a2) .or. y .gt. max(a1,a2)) return
  if (y .eq. a1) then
    x = x1
  else if (y .eq. a2) then
    x = x2
  else
    if (a1 .eq. a2) return
    t = (y-a1)/(a2-a1)
!       A convex combination avoids intercept cancellation at low rpm.
    x = (1._lrk-t)*x1+t*x2
  end if
  found = ieee_is_finite(x)
end subroutine af_interp
!
!     ==================================================================
!>    @brief Find a half-power crossing on one descending flank.
!>    @param[out] found Explicit success; x=0 rpm is a valid crossing.
subroutine getbds_checked(ym,ix,ip,lf,rpg,amp,np,mxp,mte,x,found)
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use rd_kinds, only: lrk, wp
  implicit none
  integer, intent(in) :: ix, ip, lf, np, mxp, mte
  real(lrk), intent(in) :: ym, rpg(mte)
  complex(wp), intent(in) :: amp(mxp,mte)
  real(lrk), intent(out) :: x
  logical, intent(out) :: found
  integer :: px, iy
  real(lrk) :: a0, a1
  logical :: af_curve_valid, valid

  found = .false.
  x = 0._lrk
  if (ix .lt. 1 .or. ix .gt. np .or. (lf .ne. 1 .and. lf .ne. -1)) return
  if (.not. ieee_is_finite(ym)) return
  if (ym .lt. 0._lrk) return
  if (.not. af_curve_valid(ip,rpg,amp,np,mxp,mte)) return
  px = ix
  call af_magnitude(amp(ip,px),a0,valid)
  if (a0 .lt. ym) return
  if (a0 .eq. ym) then
    x = rpg(px)
    found = .true.
    return
  end if
  do
    iy = px-lf
    if (iy .lt. 1 .or. iy .gt. np) return
    call af_magnitude(amp(ip,iy),a1,valid)
!       Stop at a reversed or flat flank above the target. Do not cross
!       a second resonance to borrow its half-power bound.
    if (a1 .ge. a0) return
    if (a1 .le. ym) then
      call af_interp(ym,rpg(px),a0,rpg(iy),a1,x,found)
      return
    end if
    px = iy
    a0 = a1
  end do
end subroutine getbds_checked
!
!     ==================================================================
!>    @brief calculates de amplification factor foe a aplitute peak,
!>    searches for a value of 0.707 x peak value and
!>    calculates the amplification factor, AF (like API 541, 4th Ed).
!
!>    @param[in] ix speed and aplitude x position index
!>    @param[in] ip number of the desired position
!>    @param[in] rpg speed vector rpm
!>    @param[in] amp complex amplitude matrix
!>    @param[in] np number of output points
!>    @param[in] mxp position, first dimension of amplitude matrix
!>    @param[in] mte speed, second dimension of amplitude matrix
!>    @param[out] st status (n)ormal or assumes the same speed on
!>     the side (i)nitial (f)inal (F)ail if nothing could be got
!>    @return the amplification factor AF for an amplitude peak.
!
real(lrk) function fatamof(ix,ip,rpg,amp,np,mxp,mte,st)
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use rd_kinds, only: lrk, wp
  implicit none
!
!     arguments
  integer :: mxp, mte, ix, ip, np
  real(lrk) :: rpg
  complex(wp) :: amp
  character(len=1) :: st
  dimension rpg(mte),amp(mxp,mte)
!
!     locals
  real(lrk) :: xc, ym, xi, xf, width, left_width, right_width
  character(len=1) :: sa(4)
  parameter (sa = (/'F','n','i','f'/))
!     function
  logical :: left_found, right_found, af_curve_valid, valid
!
  intrinsic :: abs, real
!
!     start with fail (F)
  st = sa(1)
  fatamof = -1._lrk
  if (ix .lt. 1 .or. ix .gt. np) return
  if (.not. af_curve_valid(ip,rpg,amp,np,mxp,mte)) return
  xc = rpg(ix)
  call af_magnitude(amp(ip,ix),ym,valid)
  if (ym .le. 0._lrk) return
  ym = ym/sqrt(2._lrk)
  call getbds_checked(ym,ix,ip,1,rpg,amp,np,mxp,mte,xi,left_found)
  call getbds_checked(ym,ix,ip,-1,rpg,amp,np,mxp,mte,xf,right_found)
  if (.not. left_found .and. .not. right_found) return
  left_width = 0._lrk
  right_width = 0._lrk
  if (left_found) then
    if (xi .ge. xc) return
    if (xi .lt. 0._lrk) then
      if (xc .gt. huge(width)+xi) return
    end if
    left_width = xc-xi
  end if
  if (right_found) then
    if (xf .le. xc) return
    if (xc .lt. 0._lrk) then
      if (xf .gt. huge(width)+xc) return
    end if
    right_width = xf-xc
  end if
!     Mirror only an unavailable flank. A measured zero-rpm crossing
!     remains measured. Form the width without constructing a new grid.
  if (.not. left_found) left_width = right_width
  if (.not. right_found) right_width = left_width
  if (left_width .gt. huge(width)-right_width) return
  width = left_width+right_width
  if (.not. ieee_is_finite(width)) return
  if (width .le. 0._lrk) return
  if (width .lt. 1._lrk) then
    if (abs(xc) .gt. huge(width)*width) return
  end if
!     Nc is deliberately the sampled peak speed, not maxamp's fitted vx.
  fatamof = xc/width
  st = sa(2)
  if (.not. left_found) st = sa(3)
  if (.not. right_found) st = sa(4)
!
  return
!
end function fatamof
!
!     ==================================================================
!>    @brief calculates the quadratic coefficients of a three points cur
!
!>    @param[in] i1 first position of the points in the rpg e amp matric
!>    @param[in] i2 second position of the points in the rpg e amp matri
!>    @param[in] i3 third position of the points in the rpg e amp matric
!>    @param[in] ip number of the desired position
!>    @param[out] ret return the quadratic coefficients
!>           ret(1)*x^2+ret(2)*x+ret(3)
!>    @param[in] rpg speed vector rpm
!>    @param[in] amp complex amplitude matrix
!>    @param[in] mxp position, first dimension of amplitude matrix
!>    @param[in] mte speed, second dimension of amplitude matrix
!
subroutine quad(i1,i2,i3,ip,ret,rpg,amp,mxp,mte)
  use rd_kinds, only: lrk, wp
  implicit none
!
!     arguments
  integer :: i1, i2, i3, ip, mxp, mte
  real(lrk) :: rpg, ret
  complex(wp) :: amp
  dimension ret(3),rpg(mte),amp(mxp,mte)
!
  real(lrk) :: xx, yy
  dimension xx(3),yy(3)
!
  intrinsic :: abs, real
!
  xx(1) = rpg(i1)
  yy(1) = real(abs(amp(ip,i1)), lrk)
  xx(2) = rpg(i2)
  yy(2) = real(abs(amp(ip,i2)), lrk)
  xx(3) = rpg(i3)
  yy(3) = real(abs(amp(ip,i3)), lrk)
!     calculate quadratic coefficients -> ret
  call qcfr(xx,yy,ret)
!
  return
!
end subroutine quad
!
!     ==================================================================
!>    @brief makes the analysis of the unbalance response, searching
!>    for amplification peaks above a certain amplification
!>    factor AF (much like API 541 4th Ed).
!
!>    @param[in] np number of output points
!>    @param[in] nr number of speed vector values
!>    @param[out] cn returns number of found maximums
!>    @param[in] rpg speed vector (rpm)
!>    @param[in] amp complex amplitude matrix
!>    @param[out] vf amplification factor vector
!>    @param[out] vr maximum speeds vector
!>    @param[out] vm maximums values
!>    @param[out] st status (n)ormal or assumes the same speed on
!>     the side (i)nitial (f)inal (F)ail if nothing could be got
!>    @param[in] mxp position, first dimension of amplitude matrix
!>    @param[in] mte speed, second dimension of amplitude matrix
!>    @param[out] errmsg return an error message
!>    @param[out] ok return flag. unsuccessful if <0.
!
subroutine maxamp(np,nr,cn,rpg,amp,vf,vr,vm,st,mxp,mte,errmsg,ok)
  use rd_textfun, only: fomsgf
  use rd_kinds, only: lrk, wp
  implicit none
!
!     arguments
  integer :: np, nr, mxp, mte, ok, cn
  real(lrk) :: rpg, vf, vm, vr
  character(len=1) :: st
  character(len=99) :: errmsg
  complex(wp) :: amp
  dimension cn(mxp),rpg(mte),vf(mxp,2*mxp),&
  &vm(mxp,2*mxp),vr(mxp,2*mxp),amp(mxp,mte),&
  &st(mxp,2*mxp)
!
!     locals
  character(len=1) :: stl
  character(len=3) :: cbd
  character(len=6) :: nmm
  integer :: ii, jj, i1, i2, i3
  logical :: af_curve_valid
  real(lrk) :: ld, dy, fa, dv, vx, vy, prec, cf, fatamof
  dimension cf(3)
!     minimal
  parameter(prec = 1e-12_lrk,cbd = 'mxp',nmm = 'maxamp')
!
  intrinsic :: abs, real
!
!     initialize return
  ok = -1
  errmsg = ' '
  cn = 0
  if (np .lt. 1 .or. np .gt. mxp .or. nr .lt. 1 .or. nr .gt. mte) then
    errmsg = fomsgf(99, nmm,8,'AF sample dimensions',0)
    return
  end if
  do ii = 1,np
    if (.not. af_curve_valid(ii,rpg,amp,nr,mxp,mte)) then
      errmsg = fomsgf(99, nmm,8,'AF requires finite amplitudes and ordered speeds',0)
      return
    end if
  end do
!     initial position amplitude points vector
  i1 = 1
!     ld = 0. derivative
!     number of analysis points
  do ii = 1,np
!       derivative
    ld = 0._lrk
!       init maximum counter
    cn(ii) = 0
!       number of calculated points
    do jj = 2,nr
      i2 = jj
!         delta y
      dy = real(abs(amp(ii,jj))-abs(amp(ii,(jj-1))), lrk)
!         Only the slope sign is used. The validated grid is increasing;
!         avoid division overflow on a very short, but valid interval.
      dv = dy
      if (dv .le. 0 .and. ld .gt. 0 .and. abs(dy) .gt. prec) then
        cn(ii) = cn(ii)+1
!           amplification factor
        fa = fatamof((jj-1),ii,rpg,amp,nr,mxp,mte,stl)
!           check if found
!           three points to calculate quadratic maximum
        if (jj .gt. 2) then
          i3 = jj-2
        else
          if (jj .lt. np) then
            i3 = jj+1
          else
            i3 = jj
          end if
        end if
!           calculates a parabola with 2 points and maximum
        call quad(i1,i2,i3,ii,cf,rpg,amp,mxp,mte)
!           calculates maximum presumed parabola
        call mxqr(vx,vy,cf)
        if (cn(ii) .le. (2*mxp)) then
!             amplification factor
          vf(ii,cn(ii)) = fa
!             speed
          vr(ii,cn(ii)) = vx
!             maximum amplitude
          vm(ii,cn(ii)) = vy
!             amplification status
          st(ii,cn(ii)) = stl
        else
!             'out of bounds' !4
          errmsg = fomsgf(99, nmm,4,cbd,0)
          return
        end if
!           derivative if
      end if
!
      ld = dv
      i1 = i2
!
    end do
!
  end do
!
!     return ok
  ok = 0
!
  return
!
end subroutine maxamp
!
