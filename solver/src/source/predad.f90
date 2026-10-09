!     $Id$
!     ==================================================================
!
!>    @file predad.f
!>    @brief data preparation, last changes:<br>
!>    add internal diameter block /sed/ - francisco - 03/12/2008<br>
!>    changed ump set on section - francisco 24/03/2009<br>
!>    changed divisions by defined l/d value, add +ld_r/100 on while - f
!>    add cknos - francisco 29/06/2009<br>
!>    historical note said ump => N/m (25/03/2010); current FE contract
!>    added sectmass, total sections mass and length, diskmass,
!>    total disks mass and conmass, total concentraded mass - francisco
!>    added central messages - francisco - apr-19<br>
!>    added torsional option on predad - francisco - nov-19<br>
!>    changed mxb = 99 francisco - apr-20<br>
!>    changed l/d,added last dim_sec and division dim_sec(ii+1) - franci
!>    added check p vector on predad.f for systems with just one section
!>    changed sum function names sectmass to sectmasf, diskmass to
!>     diskmasf, conmass to conmasf, added sectmaof same as sectmass
!>     without total length, added umpforf to sum all UMP forces
!>     added confor subroutine, sum all concentrated forces - francisco
!>    addeed torsion restriction divisions on predad - francisco - mar-2
!>    added dist. force like ump on predad - francisco - sep-21<br>
!>    updated function name from umpforf to disforf - francisco - sep-21
!>    added multiple ump functionality on predad - francisco - nov-21<br
!>    added dist. force angle on common /seaf/ - francisco - dec-21<br>
!     consider consider dist. force angle on predad - francisco - dec-21
!>    added direction on function disforf - francisco - dec-21.
!
!     ==================================================================
!>    @brief make the section divisions using the length / diameter
!>     ratio.
!>    changes: updated equals position to difference precision - nov-19
!
!>    @param[in] ld_r section diameter / length ratio
!>    @param[in] p sections positon vector
!>    @param[in] d section external diameters vector
!>    @param[in] ps defined sections position vector
!>    @param[in] n number of ivisions per section
!>    @param[in] dely section length
!>    @param[in] divs number of divisions each section
!>    @param[in] c number of sections plus one (+ 1)
!>    @param[in] mxp positions vector dimension
!>    @param[in] mxs diameter (d) and main section positions (ps) vector
!>    @param[in] mts vectors dely and n dimension
!>    @param[out] errmsg return an error message
!>    @param[out] ok return flag. unsuccessful if <0.
!
subroutine divdia(ld_r,p,d,ps,n,dely,divs,&
&c,mxp,mxs,mts,errmsg,ok)
  use rd_textfun, only: fomsgf
  use rd_kinds, only: lrk
  implicit none
!
!     arguments
  integer :: c, mxp, mxs, mts, ok
  real(lrk) :: ld_r
  real(lrk) :: p(mxp)
  real(lrk) :: d(mxs), ps(mxs)
  integer :: divs(mxs)
  real(lrk) :: dely(mts), n(mts)
  character(len=99) :: errmsg
!
!     locals
  integer :: ii, j, cont
  integer :: indpos
  integer :: mxo
  character(len=3) :: cbd
  character(len=6) :: nmm
  real(lrk) :: dim_s, dummy, rel, prec, xmid, seclen, tgtlen, intlen
  parameter (mxo = 150,prec = 1e-9_lrk,cbd = 'mxo',nmm = 'divdia')
!
  intrinsic :: abs, nint, max
!
!     initialize error return
  ok = -1
!
!     prepare divisions. p() may contain bearings/disks/probes inside a
!     user shaft section, therefore DIV must be resolved by the source
!     section index instead of by the p-interval index. This is essentia
!     for native conical sections, where geometry is interpolated in x.
  do ii = 1,c-1
    xmid = 0.5_lrk*(p(ii)+p(ii+1))
    j = indpos(xmid,errmsg)
    if (j .le. 0) return
    intlen = p(ii+1)-p(ii)
!
!       if number of divisions is not defined, retain historical L/D
!       refinement but evaluate D at the local conical midpoint.
    if (divs(j) .le. 0) then
      call shpdia(j,xmid,dim_s,dummy)
      cont = 1
      rel = 2*mxo
      dim_s = max(dim_s,prec)
      do while (rel .gt. ld_r+ld_r/mxo)
        n(ii) = cont
        dely(ii) = intlen/n(ii)
        rel = dely(ii)/dim_s
        cont = cont+1
        if (cont .gt. mxo) then
          errmsg = fomsgf(99, nmm,20,cbd,0)
          return
        end if
      end do
    else
!         DIV is defined for the whole user section. If mandatory statio
!         split it, preserve approximately the requested element size.
      seclen = ps(j)
      if (j .gt. 1) seclen = ps(j)-ps(j-1)
      tgtlen = seclen/real(divs(j), lrk)
      if (tgtlen .le. prec) then
        errmsg = fomsgf(99, nmm,8,' ',0)
        return
      end if
      n(ii) = max(1,nint(intlen/tgtlen))
      dely(ii) = intlen/n(ii)
    end if
!
  end do
!
!     ok
  ok = 0
!
  return
!
end subroutine divdia
!
!     ==================================================================
!>    @brief get circular area (m^2)
!
!>    @param[in] cdex external diameter (m)
!>    @param[in] cdin internal diameter (m)
!>    @return circular area (m^2)
!
real(lrk) function ciraref(cdex,cdin)
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: cdex, cdin
!
  real(lrk) :: cirare, pi, rpif
!
  pi = rpif()
  cirare = pi/4*(cdex**2-cdin**2)
  ciraref = cirare
!
  return
!
end function ciraref
!
!     ==================================================================
!>    @brief get cylinder mass (kg)
!
!>    @param[in] clen length (m)
!>    @param[in] cdex external diameter (m)
!>    @param[in] cdin internal diameter (m)
!>    @param[in] cden material density (kg/m^3)
!>    @return cylinder mass
!
real(lrk) function cylmasf(clen,cdex,cdin,cden)
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: clen, cdex, cdin, cden
!
  real(lrk) :: ciraref
  real(lrk) :: cylmas, cirare
!
  cirare = ciraref(cdex,cdin)
  cylmas = clen*cirare*cden
  cylmasf = cylmas
!
  return
!
end function cylmasf
!
!     ==================================================================
!>    @brief linearly interpolate native shaft section diameters.
!>    Supports solid/hollow cylindrical and conical sections.
!
subroutine shpdia(is,x,dout,din)
  use com_eix, only: l, d, di, ps, e, nu, rho_e, g_e, r1, cs
  use com_eixshape, only: d2, di2, etype
  use rd_kinds, only: lrk
  implicit none
  integer :: is
  real(lrk) :: x, dout, din
  integer :: mxs
  parameter (mxs = 99)
  real(lrk) :: x0, x1, rat
!
  x0 = 0._lrk
  if (is .gt. 1) x0 = ps(is-1)
  x1 = ps(is)
  rat = 0._lrk
  if (x1 .gt. x0) rat = (x-x0)/(x1-x0)
  if (rat .lt. 0._lrk) rat = 0._lrk
  if (rat .gt. 1._lrk) rat = 1._lrk
  dout = d(is)+(d2(is)-d(is))*rat
  din = di(is)+(di2(is)-di(is))*rat
  return
end subroutine shpdia
!
!     ==================================================================
!>    @brief calculates rotor sections total mass (kg)
!>    @param[out] tlen rotor total length (m)
!>    @return rotor sections total mass (kg)
!
real(lrk) function sectmasf(tlen)
  use com_eix, only: l, d, di, ps, e, nu, rho_e, g_e, r1, cs
  use com_eixshape, only: d2, di2, etype
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: tlen
!
  integer :: i
  real(lrk) :: mt, ls, sm
!     cylindrical mass function
  real(lrk) :: cylmasf
!
!     input parameters
  integer :: mxs
  parameter (mxs = 99)
!     shaft data
  real(lrk) :: avgo, avgi, pi, rpif
!
  pi = rpif()
  mt = 0
  tlen = 0
  do i = 1,cs
!       section length
    ls = ps(i)
    if (i .gt. 1)ls = ls-ps(i-1)
    tlen = tlen+ls
!       section mass. Exact volume for linearly tapered outer/inner diam
    avgo = (d(i)**2+d(i)*d2(i)+d2(i)**2)/3._lrk
    avgi = (di(i)**2+di(i)*di2(i)+di2(i)**2)/3._lrk
    sm = rho_e(i)*pi/4._lrk*ls*(avgo-avgi)
    mt = mt+sm
  end do
!
  sectmasf = mt
!
  return
!
end function sectmasf
!
!     ==================================================================
!>    @brief calculates rotor sections total mass only (kg).
!      Convenience function without total lenght.
!>    @see sectmasf
!>    @return rotor sections total mass (kg)
!
real(lrk) function sectmaof()
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: tl, sectmasf
!
  sectmaof = sectmasf(tl)
!
  return
!
end function sectmaof
!
!     ==================================================================
!>    @brief calculates rotor disks total mass (kg)
!>    @return rotor disks total mass (kg)
!
real(lrk) function dskmasf()
  use com_dis, only: pd, d_d, h_d, rho_d, r2, nd
  use com_dsc, only: md, idx, idy
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: sumv_r
!
!     input parameters
  integer :: mxd
  parameter (mxd = 99)
!     disks
!     disks parameters block

!     disks parameters block
!
  dskmasf = sumv_r(md,mxd,nd)
!
  return
!
end function dskmasf
!
!     ==================================================================
!>    @brief calculates rotor concentrated total mass (kg)
!>    @return rotor concentrated total mass (kg)
!
real(lrk) function conmasf()
  use com_conc, only: nmic, psic, vlmc, ixic, iyic, izic
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: sumv_r
!
!     concentrated masses and inertias
  integer :: mxic
  parameter (mxic = 15)
!
  conmasf = sumv_r(vlmc,mxic,nmic)
!
  return
!
end function conmasf
!
!     ==================================================================
!>    @brief get sum dist. force on sections.
!>     By convention dist. force is a down force, negative z direction.
!>    @param[in] isx true for x axis, y else.
!>    @return sum of dist. force on sections.
!
real(lrk) function disforf(isx)
  use com_seaf, only: dfc, dfa
  use com_sec, only: n, y, nt, nn
  use rd_kinds, only: lrk
  implicit none
!
  logical :: isx
!
!     input parameters
  integer :: mxs
  parameter (mxs = 99)
!
  real(lrk) :: sl, vl, disfor, riff
  integer :: ii
!
!     total number of sections
  integer :: mts
  parameter (mts = 999)
!     all sections (divisions)
!     dist. force - francisco sep-21
!     dist. force angle - francisco nov-21
!
  intrinsic :: cos, sin
!
  disfor = 0
  do ii = 2,nt
!       section length
    sl = y(ii)-y(ii-1)
    vl = riff (isx, cos(dfa(ii-1)),sin(dfa(ii-1)))
    disfor = disfor+dfc(ii-1)*sl*vl
  end do
!
  disforf = disfor
!
  return
!
end function disforf
!
!     ==================================================================
!>    @brief get sum of concentrated forces on x and z directions
!
!>    @param[out] tcfx total concentrated force x direction (N)
!>    @param[out] tcfz total concentrated force z direction (N)
!
subroutine confor(tcfx,tcfz)
  use rd_textfun, only: cadjf
  use com_mfa, only: ma, rm, au
  use com_unb1, only: ndd, mu, ed, tpf, nb
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: tcfx, tcfz
!
  integer :: ii
  logical :: isr
  real(lrk) :: an, toradf, riff
  character(len=1) :: crd, crdv
  dimension crdv(2)
  parameter(crdv = (/'r','R'/))
!
  integer :: mxb
  parameter (mxb = 99)
!     ndd = position, mu = unbalance, ed = phase
!     tpf = kind of force
!     -1:transient torque,0:unbalance (default),1:concentrated,
!      2:harmonic torque,3:static torque,4:freq. response,5:dist. force
!     min amplification factor fator, modal rpm, angle unit block
!     angle unit r -> radian, default degree
!
  intrinsic :: cos, sin
!
!     check for force angle in radians
  crd = cadjf(1, au,1)
  isr = crd .eq. crdv(1) .or. crd .eq. crdv(2)
  !
  tcfx = 0
  tcfz = 0
  do ii = 1,nb
!       check force kind 1=concentrated
    if (tpf(ii) .eq. 1) then
!         check unit, deg -> rad
      an = riff(.not. isr,toradf(ed(ii)),ed(ii))
      tcfx = tcfx+mu(ii)*cos(an)
      tcfz = tcfz+mu(ii)*sin(an)
    end if
  end do
  !
  return
!
end subroutine confor
!
!     ==================================================================
!>    @brief get shear modulus fron Young and Poisson
!
!>    @param [in] young Young modulus
!>    @param [in] poisson Poisson ratio
!>    @return shear modulus from Young and Poisson
!
real(lrk) function shearf(young,poisson)
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: young, poisson
!
  real(lrk) :: dm, shear
!
  dm = 2*(1+poisson)
  shear = young/dm
  shearf = shear
!
  return
!
end function shearf
!
!     ==================================================================
!>    @brief get second moment of inertia of circular section
!
!>    @param[in] sdex external diameter (m)
!>    @param[in] sdin internal diameter (m)
!>    @return second moment of inertia of circular section
!
real(lrk) function scmicsf(sdex,sdin)
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: sdex, sdin
!
  real(lrk) :: rpif
  real(lrk) :: pi, dm, scmics
!
  pi = rpif()
  dm = (sdex**4)-(sdin**4)
!
  scmics = pi*dm/64.0_lrk
  scmicsf = scmics
!
  return
!
end function scmicsf
!
!     ==================================================================
!>    @brief get disk mass moment of inertia.
!
!>    @param[in] dlen length (m)
!>    @param[in] ddex external diameter (m)
!>    @param[in] ddin internal diameter (m)
!>    @param[in] dmas mass (kg)
!>    @return disk mass moment of inertia
!
real(lrk) function mmmidkf(dlen,ddex,ddin,dmas)
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: dlen, ddex, ddin, dmas
  real(lrk) :: mmmidk, smindkf
!
  mmmidk = 0.5_lrk*smindkf(ddex,ddin,dmas)+dmas/12.0_lrk*dlen**2
  mmmidkf = mmmidk
!
  return
!
end function mmmidkf
!
!     ==================================================================
!>    @brief get disk second mass moment of inertia.
!
!>    @param[in] ddex external diameter (m)
!>    @param[in] ddin internal diameter (m)
!>    @param[in] dmas mass (kg)
!>    @return disk second mass moment of inertia
!
real(lrk) function smindkf(ddex,ddin,dmas)
  use rd_kinds, only: lrk
  implicit none
!
  real(lrk) :: ddex, ddin, dmas
!
  real(lrk) :: smindk
!
  smindk = dmas/8.0_lrk*(ddex**2+ddin**2)
  smindkf = smindk
!
  return
!
end function smindkf
!
!     ==================================================================
!>    @brief get section gyroscopic factor for a given section index.
!>     compensates equivalent diameter. returns one by default.
!>    @param[in] is index of a section
!>    @return section gyroscopic factor for the given section index or
!>     one if not found.
!
real(lrk) function gycscf(is)
  use com_gycsedc, only: gycsedid, gycsedvl, ngycsed
  use rd_kinds, only: lrk
  implicit none
  integer :: is
!
  integer :: mxgc
  parameter (mxgc = 5)
!
  real(lrk) :: gycsc
  integer :: ii
!
  gycsc = 1
  do ii = 1,ngycsed
    if (gycsedid(ii) .eq. is) then
      gycsc = gycsedvl(ii)
      exit
    end if
  end do
!
  gycscf = gycsc
!
  return
!
end function gycscf
!
!     ==================================================================
!>    @brief get excitation positions.
!>     positions and dist. force section index.
!
!>    @param[in] nb total number of excitations (entrada)
!>    @param[in] mxs dimension of section related vectors
!>    @param[in] mxb dimension of excitation related vectors
!>    @param[in] tpf kind of excitation vector:
!>      -1:transient torque,0:unbalance (default),1:concentrated,
!>       2:harmonic torque,3:static torque,4:freq. response,5:dist.force
!>    @param[in] ndd position of excitations (dist. force = section inde
!>    @param[in] mu vector of excitations (entrada)
!>    @param[in] ed vector of excitation angles (entrada)
!>    @param[in] ps vector of section positions (entrada)
!>    @param[out] ifd dist. force section position index vector
!>    @param[out] vf dist. force value, force/length vector (N/m)
!>    @param[out] an dist. force angle (rad)
!>    @param[out] ep other excitation position vector (m)
!>    @param[out] nfd number of dist. force
!>    @param[out] no number of other excitations (except dist. force)
!>    @param[out] ok result code, 0 ok, <0 error:
!>     -1 out of mxs bound,-2 out of mxb bound,-3 section length<=0.
!
subroutine getexps(nb,mxs,mxb,tpf,ndd,mu,ed,ps,&
&ifd,vf,an,ep,nfd,no,ok)
  use rd_textfun, only: cadjf
  use com_mfa, only: ma, rm, au
  use rd_kinds, only: lrk
  implicit none
!
  integer :: nb, mxs, mxb, tpf, ifd, nfd, no, ok
  real(lrk) :: ndd, mu, ed, ps, vf, an, ep
  dimension tpf(mxb),ndd(mxb),mu(mxb),ed(mxb),ps(mxs),&
  &ifd(mxs),vf(mxs),an(mxs),ep(mxb)
!
!     min amplification factor fator, modal rpm, angle unit block
!     angle unit r -> radian, default degree
!
  character(len=1) :: crd, crdv
  dimension crdv(2)
  parameter(crdv = (/'r','R'/))
  logical :: isr
  integer :: i, j
  real(lrk) :: sl, riff, toradf
!
  intrinsic :: nint
!
!     get excitation positions
!
  ok = 0
!
!     check for force angle in radians
  crd = cadjf(1, au,1)
  isr = crd .eq. crdv(1) .or. crd .eq. crdv(2)
!
  no = 0
  nfd = 0
  do i = 1,nb
    if (i .gt. mxb) then
      ok = -2
      return
    end if
!       check dist. force
    if (tpf(i) .eq. 5) then
!         dist. force
      nfd = nfd+1
!         check mxs bound
      if (nfd .gt. mxs) then
        ok = -1
        return
      end if
!         section index, index number check on entrada
      j = nint(ndd(i))
!         store index
      ifd(nfd) = j
!         section length
      if (j .eq. 1) then
        sl = ps(1)
      else
        sl = ps(j)-ps(j-1)
      end if
!         check length
      if (sl .le. 0) then
        ok = -3
        return
      end if
!         calculate dist. force / m
      vf(nfd) = mu(i)/sl
!         check unit, deg -> rad
      an(nfd) = riff(.not. isr,toradf(ed(i)),ed(i))
    else
!         other excitation except dist. force
      no = no+1
!         check mxb bound
      if (no .gt. mxb) then
        ok = -2
        return
      end if
      ep(no) = ndd(i)
    end if
  end do
!
  return
!
end subroutine getexps
!
!     ==================================================================
!>    @brief matrices data preparation.
!
!>    @param[out] tors torsional option flag
!>    @param[out] errmsg return an error message
!>    @param[out] ok return flag. unsuccessful if <0.
!
subroutine predad(tors,errmsg,ok)
  use rd_textfun, only: femsgf, fomsgf
  use com_conc, only: nmic, psic, vlmc, ixic, iyic, izic
  use com_dis, only: pd, d_d, h_d, rho_d, r2, nd
  use com_disa, only: d_i, i_x, i_y, m_d
  use com_divinf, only: sdv, sde
  use com_dsc, only: md, idx, idy
  use com_eix, only: l, d, di, ps, e, nu, rho_e, g_e, r1, cs
  use com_eixa, only: divs, umps
  use com_eixshape, only: d2, di2, etype
  use com_eqvlen, only: teql, tsl
  use com_fillets, only: ntfil, tfilid, tfilrd
  use com_pse, only: v_maior, v_menor
  use com_psea, only: ld_r
  use com_sea, only: rs, es, gs, dely, s, ie, ump
  use com_seaf, only: dfc, dfa
  use com_sec, only: n, y, nt, nn, elemsec
  use com_sed, only: ds, di_d, di_s
  use com_seg, only: gfc
  use com_tman, only: ntbr, tpc, tkk, tcc, tjj, sct
  use com_unb0, only: pr, desp, ori, np, nm
  use com_unb1, only: ndd, mu, ed, tpf, nb
  use com_ymc, only: nbrg, rks, pc
  use rd_kinds, only: lrk
  implicit none
!
!     arguments
!     torsional option - francisco - nov-19.
  logical :: tors
  integer :: ok
  character(len=99) :: errmsg
!
!     locals
  character(len=1) :: blank
  character(len=3) :: cds
  character(len=6) :: nmm
!     position index function
  integer :: c, i, j, k, ll, ii, mps, nfd, indpos
  dimension cds(5)
  parameter(blank = ' ',nmm = 'predad',&
  &cds = (/'mxp','mxs','mts','mxb','ump'/))
!
  real(lrk) :: d1, d1i, dn, dni, xmid, mv, dm, rtol, seclen, tgtlen, intlen, xlo
!     functions
  real(lrk) :: ciraref, shearf, scmicsf, cylmasf, mmmidkf, smindkf, gycscf
!     gycscf->gyroscopic section compensation for equivalent diameters
!
!     precision
  real(lrk) :: prec, mins
  parameter (mins = 0.1_lrk,prec = 1e-12_lrk)
!
!     input parameters
  integer :: mxs, mxd, mxm, mxb, mxr
  parameter (mxs = 99,mxd = 99,mxm = 9,mxb = 99,mxr = 9)
!
!     total number of sections
  integer :: mts
  parameter (mts = 999)
!
!     shaft
!
!     shaft parameters block
!     unbalanced magnetic pull distributed stiffness k' [N/m2]
!
!     sections
!     sections parameters block
!
!
!     disks
!     disks parameters block

!     disks parameters block
!
!     disks parameters block
!
!     bearings
!     added 13/04/2007
!     torsion restriction bearings, added mar-21
!
!     unbalance parameters block
!     tpf = kind of force
!      -1:transient torque,0:unbalance (default),1:concentrated,
!       2:harmonic torque,3:static torque,4:freq. response,5:dist.force
!
!     response/probe positions. Positive positions are mandatory FEM
!     stations; negative values retain the historical support reference.
!
!     concentraded mass and inertia block
  integer :: mxic
  parameter (mxic = 15)
!
!     torsional, see tentrada.f
!     section fillets
  integer :: mxtfil
  parameter (mxtfil = 20)
!     number of section fillets
!     section ids
!     section fillets
!
!     local variables
  integer :: oki, mxp, ifd, nrp
!     maximal number of positions; include physical response/probe sites
  parameter (mxp = 1+mxs+mxd+2*mxm+mxb+mxic+mxr)
  real(lrk) :: pp, p, vf, an, ep, rpp
  dimension pp(mxp),p(mxp),rpp(mxr)&
!     distributed force section indices
  &,vf(mxs),an(mxs),ifd(mxs),ep(mxb)
!
!     torsional related
  integer :: mtt
  parameter (mtt = mts)
!     subdivisions,external diameters
!     section equivalent length,division equivalent length
!
!     all sections (divisions)
!
!     additional data by section
!     dist. force - francisco sep-21
!     dist. force angle - francisco nov-21
!     added gyroscopic section compensation for equivalent diameters
!     franciscp - aug-21
!
!     section diameters
!
  intrinsic :: abs, nint
!
!     initialize return
  ok = -1
  pp=0._lrk
  p=0._lrk
  rpp=0._lrk
  ifd=0
  vf=0._lrk
  an=0._lrk
  ep=0._lrk
  n=0._lrk
  y=0._lrk
  dely=0._lrk
  elemsec=0
  tsl=0._lrk
  teql=0._lrk
  sdv=0._lrk
  sde=0._lrk
!
!     parameters check
!
!     number of sections
  if (cs .le. 0 .or. cs .gt. mxs) then
    errmsg = femsgf(99, nmm,8,16,0)
    return
  end if
!     shaft number of divisions parameters
  if (v_maior .le. 0 .or. v_menor .le. 0)then
    errmsg = femsgf(99, nmm,8,15,0)
    return
  end if
!
!     Physical boundaries are authoritative. Insert them first and never
!     merge them using a component/probe tolerance. A missing final input
!     section has no material/shape owner and cannot be invented here.
  rtol=32._lrk*epsilon(1._lrk)*max(1._lrk,abs(l))
  if (abs(ps(cs)-l).gt.rtol) then
    write(errmsg,'(a,es14.6,a,es14.6)') &
      'predad: final section ',ps(cs),' must end at LENGTH ',l
    return
  endif
  c=cs+1
  p(1)=0._lrk
  p(2:c)=ps(1:cs)
  do i=1,cs
    if(p(i+1).le.p(i)) then
      errmsg='predad: physical section boundaries must be strictly increasing'
      return
    endif
  enddo

!     Response positions: negative values retain support-reference meaning.
  nrp = 0
  if (.not. tors) then
    do i = 1,np
      if (pr(i) .ge. 0._lrk) then
        nrp = nrp+1
        rpp(nrp) = pr(i)
      endif
    enddo
  endif
!
!     get excitation positions
!     except dist. force
!
  call getexps(nb,mxs,mxb,tpf,ndd,mu,ed,ps,&
  &ifd,vf,an,ep,nfd,k,oki)
!     ifd dist. force section position index vector
!     vf dist. force value, force/length vector (N/m)
!     an dist. force angle (rad)
!     ep other excitation position vector (m)
!     nfd number of dist. force
!     k number of other excitations (except dist. force)
!     oki result code, 0 ok, <0 error:
!     -1 out of mxs bound,-2 out of mxb bound,-3 section length<=0.
  if (oki .lt. 0) then
!       'out of bounds' !4
    if (oki .eq. -1) errmsg = fomsgf(99, nmm,4,cds(2),0)
    if (oki .eq. -2) errmsg = fomsgf(99, nmm,4,cds(4),0)
!       'invalid data ' !8
    if (oki .eq. -3) errmsg = fomsgf(99, nmm,8,blank,0)
    return
  end if
!
!     Count only point excitations, not distributed-force section IDs.
  ll=0
  pp(ll+1:ll+nd)=pd(1:nd)
  ll=ll+nd
  pp(ll+1:ll+nbrg)=pc(1:nbrg)
  ll=ll+nbrg
  pp(ll+1:ll+ntbr)=tpc(1:ntbr)
  ll=ll+ntbr
  pp(ll+1:ll+k)=ep(1:k)
  ll=ll+k
  pp(ll+1:ll+nmic)=psic(1:nmic)
  ll=ll+nmic
  pp(ll+1:ll+nrp)=rpp(1:nrp)
  mps=ll+nrp

!     Add every distinct component/probe station without moving a physical
!     boundary. Only roundoff-level coincidence is merged; endpoints already
!     stored in p take precedence over the inserted point.
  do i=1,mps
    if(pp(i).lt.-rtol.or.pp(i).gt.l+rtol) then
      write(errmsg,'(a,es14.6,a,es14.6)') &
        'predad: component/probe position ',pp(i),' outside shaft LENGTH ',l
      return
    endif
    if(any(abs(p(1:c)-pp(i)).le.rtol)) cycle
    c=c+1
    if(c.gt.mxp) then
      errmsg=fomsgf(99,nmm,4,cds(1),0)
      return
    endif
    p(c)=pp(i)
  enddo
  call ordena_r(p,p,c,mxp,0)
!
!     poisson and external radius. UMP remains attached to the
!     authoritative physical source section through umps(i); it is not
!     remapped through the merged station vector p().
  do i = 1,cs
!       shear
    g_e(i) = shearf(e(i),nu(i))
!       external radius
    r1(i) = d(i)/2._lrk
  end do
!
!     searches for the biggest distance between two adjacent points
  ii = 0
  mv = 0._lrk
!     starts with index two (2), first is zero
  do i = 2, c
!       distance is the difference between two position points
    dm = p(i)-p(i-1)
    if (dm .gt. mv) then
!         store maximal index, used bellow
      ii = i-1
      mv = p(i)-p(ii)
    end if
  end do
!
!     if diameter / length is not defined
  if (ld_r .le. 0) then
!
!       goes up to c-1
    ll = c-1
    do i = 1,ll
      k = i+1
!         p() may contain mandatory stations inside a source section.
!         Resolve DIV and geometry from that source section, not from i.
      xmid = 0.5_lrk*(p(i)+p(k))
      j = indpos(xmid,errmsg)
      if (j .le. 0) return
      intlen = p(k)-p(i)
!
!         if number of divisions is not defined
      if (divs(j) .le. 0) then
        if (i .eq. ii) then
          n(i) = v_maior
        else
          n(i) = v_menor
        end if
      else
!           DIV belongs to the full user section. Preserve its target
!           element length when bearings/disks/probes split the interval
        seclen = ps(j)
        if (j .gt. 1) seclen = ps(j)-ps(j-1)
        tgtlen = seclen/real(divs(j), lrk)
        if (tgtlen .le. prec) then
          errmsg = fomsgf(99, nmm,8,blank,0)
          return
        end if
        n(i) = max(1,nint(intlen/tgtlen))
      end if
!
!         for sections with length less than 10% of local diameter,
!         set the number of divisions to one
      call shpdia(j,xmid,d1,d1i)
      mv = mins*d1
      if (intlen .lt. mv) n(i) = 1
!
!         calculates the delta Y (dely), distance between divisions
      dely(i)=intlen/n(i)
!
    end do
!
  else
!       diameter / length is defined, calculates correspondent dely
    call divdia(ld_r,p,d,ps,n,dely,divs,&
    &c,mxp,mxs,mts,errmsg,oki)
!       error return
    if (oki .lt. 0) return
!
  end if
!
!     additionl torsional equivalent section length -> teql
!     see tpredad.f
  if (tors) then
    call teqvlen(d,tfilrd,tfilid,teql,cs,ntfil,mxtfil,mxs)
  end if
!
!     nodal positions
  k = 1
  y(1) = 0._lrk
!     gyroscopic section compensation for equivalent diameters
  gfc(1) = 1
!
  nn = c-1
  do i = 1,nn
!       Midpoint lookup is safe only after every physical boundary was
!       preserved. Check the entire interval and record its element owner.
    xmid=0.5_lrk*(p(i)+p(i+1))
    ii=indpos(xmid,errmsg)
    if(ii.le.0.or.ii.gt.cs) return
    xlo=0._lrk
    if(ii.gt.1) xlo=ps(ii-1)
    if(p(i).lt.xlo-rtol.or.p(i+1).gt.ps(ii)+rtol) then
      errmsg='predad: finite element would cross a physical section boundary'
      return
    endif
!       Retain section metadata through this same validated owner. The old
!       independent 1e-12 boundary match could advance twice when a component
!       lies just before a boundary, including beyond the final source section.
    sdv(ii)=sdv(ii)+1._lrk
    sde(ii)=d(ii)
!       section divisions
    ll = nint(n(i))
    do j = 1, ll
!         first element should be zero
      k = k+1
!         check maximal vector dimension
      if (k .gt. mts) then
        errmsg = fomsgf(99, nmm,4,cds(3),0)
        return
      end if
!         section divisions
      y(k) = p(i)+(dely(i)*j)
!         Mandatory positions remain bitwise equal to the original input.
      if(j.eq.ll) y(k)=p(i+1)
      elemsec(k-1)=ii
!         gyroscopic section compensation for equivalent diameters
      gfc(k) = 1
    end do
  end do
!
!     number of total nodes
  nt = k
!
!     Every finite element obtains all physical properties from its owner.
!     ds(k+1)/di_s(k+1) retain the historical left-element end convention
!     at a diameter step; A and I are evaluated at the conical midpoint.
  ds(1)=d(1)
  di_s(1)=di(1)
  do k=1,nt-1
    i=elemsec(k)
    xmid=0.5_lrk*(y(k)+y(k+1))
    call shpdia(i,xmid,d1,d1i)
    s(k)=ciraref(d1,d1i)
    ie(k)=scmicsf(d1,d1i)
    rs(k)=rho_e(i)
    es(k)=e(i)
    gs(k)=g_e(i)
    gfc(k)=gycscf(i)
!       Preserve the existing strict UMP cutoff and section-local units.
    ump(k)=0._lrk
    if(umps(i).gt.mins) ump(k)=umps(i)
    dfc(k)=0._lrk
    dfa(k)=0._lrk
    do j=1,nfd
      if(ifd(j).eq.i) then
        dfc(k)=vf(j)
        dfa(k)=an(j)
        exit
      endif
    enddo
    if(tors) then
      seclen=ps(i)
      if(i.gt.1) seclen=ps(i)-ps(i-1)
!         Distribute equivalent length by physical element length. The
!         source-section sum is independent of inserted stations and DIV.
      tsl(k)=teql(i)*(y(k+1)-y(k))/seclen
    endif
    call shpdia(i,y(k+1),dn,dni)
    ds(k+1)=dn
    di_s(k+1)=dni
  enddo
!
!     disk properties
  if (nd .gt. 0) then
!
    do k = 1,nd
!
!         search shaft position for disk positions
      j = indpos(pd(k),errmsg)
!         if not found, error return
      if (j .lt. 0) return
!
!         if internal disk diameter is not defined
!         internal diameter same as shaft external ones
      if (d_i(k) .le. 0) then
!
!           local shaft diameter (supports native conical sections)
        call shpdia(j,pd(k),d1,d1i)
        di_d(k) = d1
!           for output
        d_i(k) = di_d(k)
      else
!
!           internal diameter  (was section external)
        di_d(k) = d_i(k)
      end if
!
!         external radius disk k
      r2(k) = d_d(k)/2.0_lrk
!
!         disk mass
!         if disk mass was not defined
      if (m_d(k) .le. 0._lrk) then
!           calculates disk mass
        md(k) = cylmasf(h_d(k),d_d(k),di_d(k),rho_d(k))
!           for output
        m_d(k) = md(k)
      else
!           disk mass is defined
        md(k) = m_d(k)
      end if
!
!         inertia
!         if disk inertia was not defined
      if (i_x(k) .le. 0._lrk) then
!           calculates disk inertia
        idx(k) = mmmidkf(h_d(k),d_d(k),di_d(k),md(k))
!           for output
        i_x(k) = idx(k)
      else
!           disk inertia is defined
        idx(k) = i_x(k)
      end if
!
!         if disk second order inertia was not defined
      if (i_y(k) .le. 0._lrk) then
        idy(k) = smindkf(d_d(k),di_d(k),md(k))
!           for output
        i_y(k) = idy(k)
      else
!           disk second order inertia is defined
        idy(k) = i_y(k)
      end if
!         end disk loop
    end do
!       end have disk if
  end if
!
!     finalize/validate flexible disk reduced properties after Id/Ip
!     have been computed or accepted from input.
  call flexdisk_finalize(errmsg,ok)
  if (ok .lt. 0) return
!
!     return ok
  ok = 0
!
  return
!
end subroutine predad
!
!     ==================================================================
!>    Shaft source integrals and the actual uniform-midpoint FE integrals.
!>    Components: mass, axial first/second mass moments, diametral rotary
!>    inertia, polar inertia, and polar coefficient weighted by GYCOF.
!>    Three-point Gauss is exact for these degree <= 4 taper polynomials.
!>    This is an audit, not a change to the existing conical FE formulation.
subroutine shaft_geometry_integrals(source,mesh)
  use com_eix, only: cs, ps, d, di, rho_e
  use com_eixshape, only: d2, di2
  use com_sea, only: rs, s, ie
  use com_sec, only: y, nt
  use com_seg, only: gfc
  use rd_kinds, only: lrk
  implicit none
  real(lrk), intent(out) :: source(6), mesh(6)
  real(lrk) :: absc(3), weight(3), x0, dx, x, de, dint, area, iner, fac, pi, gf, mass
  real(lrk) :: gycscf
  integer :: i, j
  pi=acos(-1._lrk)
  absc=[0.5_lrk-sqrt(0.6_lrk)/2._lrk,0.5_lrk,0.5_lrk+sqrt(0.6_lrk)/2._lrk]
  weight=[5._lrk/18._lrk,4._lrk/9._lrk,5._lrk/18._lrk]
  source=0._lrk
  mesh=0._lrk
  x0=0._lrk
  do i=1,cs
    dx=ps(i)-x0
    gf=gycscf(i)
    do j=1,3
      x=x0+dx*absc(j)
      de=d(i)+(d2(i)-d(i))*absc(j)
      dint=di(i)+(di2(i)-di(i))*absc(j)
      area=pi*(de**2-dint**2)/4._lrk
      iner=pi*(de**4-dint**4)/64._lrk
      fac=rho_e(i)*dx*weight(j)
      source=source+fac*[area,area*x,area*x*x,iner,2._lrk*iner,2._lrk*iner*gf]
    enddo
    x0=ps(i)
  enddo
  do i=1,nt-1
    dx=y(i+1)-y(i)
    mass=rs(i)*s(i)*dx
    mesh(1)=mesh(1)+mass
    mesh(2)=mesh(2)+mass*(y(i)+y(i+1))/2._lrk
    mesh(3)=mesh(3)+mass*(y(i)**2+y(i)*y(i+1)+y(i+1)**2)/3._lrk
    mesh(4)=mesh(4)+rs(i)*ie(i)*dx
    mesh(5)=mesh(5)+2._lrk*rs(i)*ie(i)*dx
    mesh(6)=mesh(6)+2._lrk*rs(i)*ie(i)*dx*gfc(i)
  enddo
end subroutine shaft_geometry_integrals
!
subroutine shaft_geometry_report(iu)
  use com_conc, only: nmic, psic, vlmc
  use com_dis, only: nd, pd
  use com_doff, only: off_d
  use com_dsc, only: md
  use com_eix, only: cs
  use com_eixshape, only: etype
  use com_eqvlen, only: teql, tsl
  use com_sec, only: nt, elemsec
  use rd_kinds, only: lrk
  implicit none
  integer, intent(in) :: iu
  real(lrk) :: source(6), mesh(6), total, first, tsum
  integer :: i, k
  character(len=30), parameter :: label(6)=[character(len=30) :: &
    'SHAFT_MASS_KG', 'AXIAL_FIRST_MOMENT_KG_M', 'AXIAL_SECOND_MOMENT_KG_M2', &
    'DIAMETRAL_ROTARY_INERTIA_KG_M2', 'POLAR_INERTIA_KG_M2', 'GYRO_COEFFICIENT_KG_M2']
  call shaft_geometry_integrals(source,mesh)
  write(iu,'(a)') 'GEOMETRY INTEGRALS  : SOURCE_EXACT / FE_MIDPOINT / FE_MINUS_SOURCE'
  do i=1,6
    write(iu,'(a30,3(1x,es24.16))') label(i),source(i),mesh(i),mesh(i)-source(i)
  enddo
  write(iu,'(a,2(1x,es24.16))') 'SHAFT_TRANSVERSE_ORIGIN_KG_M2', &
    source(3)+source(4),mesh(3)+mesh(4)
  total=source(1)+sum(md(1:nd))+sum(vlmc(1:nmic))
  first=source(2)+sum(md(1:nd)*(pd(1:nd)+off_d(1:nd)))+sum(vlmc(1:nmic)*psic(1:nmic))
  if(total.gt.0._lrk) write(iu,'(a,es24.16)') 'SOURCE ROTOR CG (m) : ',first/total
  write(iu,'(a)') 'SECTION OWNERSHIP  : SECTION ETYPE ELEMENTS EQUIV_LENGTH_SUM EQUIV_LENGTH_SOURCE'
  do i=1,cs
    k=count(elemsec(1:max(0,nt-1)).eq.i)
    tsum=sum(tsl(1:max(0,nt-1)),mask=elemsec(1:max(0,nt-1)).eq.i)
    write(iu,'(3i9,2(1x,es24.16))') i,etype(i),k,tsum,teql(i)
  enddo
  write(iu,'(a)') 'CONE DISCRETIZATION: midpoint diameters; assess convergence against SOURCE_EXACT'
end subroutine shaft_geometry_report
