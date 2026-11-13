"""Reference-visible expedition equipment: tailored plates, brass, straps, fins."""
import math
from mathutils import Vector


def build(api):
    tau=math.tau
    def box(name,center,size,material,driver='body',bevel=.002):
        import bpy
        x,y,z=center; a,b,c=[v/2 for v in size]
        verts=[(x+sx*a,y+sy*b,z+sz*c) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        obj=api.surface(name,verts,faces,material,driver)
        if bevel:
            mod=obj.modifiers.new('Hand finished edge','BEVEL');mod.width=bevel;mod.segments=2
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
        return obj

    def loop(name,center,rx,rz,y,material='gold',driver='body',thickness=.0022,segs=40):
        pts=[(center[0]+rx*math.cos(i/segs*tau),y,center[2]+rz*math.sin(i/segs*tau)) for i in range(segs+1)]
        return api.tube(name,pts,[thickness]*(segs+1),material,driver,sides=8)

    def cylinder_domed(name,center,rx,rz,y0,y1,material,driver='body',segs=28,cap_rings=5):
        cx,_,cz=center; verts=[]; uv=[]; faces=[]
        r_avg=(rx+rz)*.5; ys=[]
        for i in range(cap_rings):
            a=math.pi*.5*(1-i/cap_rings)
            ys.append((y1+r_avg*math.sin(a),math.cos(a)))
        for i in range(6):
            t=i/5; ys.append((y1*(1-t)+y0*t,1.0))
        for i in range(1,cap_rings+1):
            a=math.pi*.5*(i/cap_rings)
            ys.append((y0-r_avg*math.sin(a),math.cos(a)))
        verts.append((cx,ys[0][0]+.001,cz)); uv.append((.5,1.0))
        ring_rows=ys[1:-1]
        for r_i,(yy,sc) in enumerate(ring_rows):
            for j in range(segs):
                ang=j/segs*tau
                verts.append((cx+rx*sc*math.cos(ang),yy,cz+rz*sc*math.sin(ang)))
                uv.append((j/segs,1-r_i/max(1,len(ring_rows)-1)))
        bot_idx=len(verts); verts.append((cx,ys[-1][0]-.001,cz)); uv.append((.5,0.0))
        for j in range(segs):
            j1=(j+1)%segs
            faces.append((0,1+j1,1+j))
            for r_i in range(len(ring_rows)-1):
                a=1+r_i*segs+j; b=1+r_i*segs+j1
                faces.append((a,b,b+segs,a+segs))
            last_r=1+(len(ring_rows)-1)*segs
            faces.append((bot_idx,last_r+j,last_r+j1))
        return api.surface(name,verts,faces,material,driver,uv=uv)

    def buckle(name,at,width=.018,height=.021,driver='body'):
        x,y,z=at; r=.0025
        pts=[]
        for cx,cy,start in [(x+width/2-r,y+height/2-r,0),(x-width/2+r,y+height/2-r,90),
                            (x-width/2+r,y-height/2+r,180),(x+width/2-r,y-height/2+r,270)]:
            for j in range(4):
                a=math.radians(start+j/3*90)
                pts.append((cx+r*math.cos(a),cy+r*math.sin(a),z))
        pts.append(pts[0])
        api.tube(name+'Frame',pts,[.0018]*len(pts),'gold',driver,sides=7)
        api.tube(name+'Tongue',[(x,y-height*.34,z-.001),(x,y+height*.26,z-.001)],[.0011,.0011],'gold_light',driver,sides=6)

    def wrapped_armor_plate(name,driver,side_sign,rows_spec,mat='armor',rim_mat='gold_light',voronoi_veins=True,thick=.0035):
        cols=19; verts=[]; uv=[]; faces=[]
        seeds=[(.22,.24),(.52,.19),(.79,.27),(.18,.53),(.46,.49),(.74,.55),(.31,.78),(.63,.81),(.50,.66)]
        def cell_relief(u01,v01):
            if not voronoi_veins:return 0.0
            ds=sorted((u01-sx)**2+(v01-sy)**2 for sx,sy in seeds)
            edge=math.sqrt(ds[1])-math.sqrt(ds[0])
            return -.0011*math.exp(-(edge/.028)**2)+.0006*(1.0-min(1.0,ds[0]/.04))
        outer_grid=[]
        for shell in (0,1):
            dr=0.0 if shell==0 else -thick
            for r_i,(yb,cx,cz,rx,rz,arc,scallop) in enumerate(rows_spec):
                v01=r_i/max(1,len(rows_spec)-1)
                row_pts=[]
                for j in range(cols):
                    u=j/(cols-1)*2-1; u01=(u+1)*.5; ang=u*arc
                    rel=cell_relief(u01,v01) if shell==0 else 0.0
                    rr_x=max(.002,rx+dr+rel); rr_z=max(.002,rz+dr+rel)
                    px=cx+side_sign*rr_x*math.cos(ang); pz=cz+rr_z*math.sin(ang)
                    py=yb+scallop*math.cos(u*math.pi*1.5)
                    verts.append((px,py,pz)); uv.append((u01,v01))
                    if shell==0:row_pts.append((px,py,pz))
                if shell==0:outer_grid.append(row_pts)
        stride=len(rows_spec)*cols
        for sh in (0,1):
            for i in range(len(rows_spec)-1):
                for j in range(cols-1):
                    k=sh*stride+i*cols+j; q=(k,k+1,k+cols+1,k+cols)
                    faces.append(q if (sh==0 and side_sign<0) or (sh==1 and side_sign>0) else tuple(reversed(q)))
        for i in range(len(rows_spec)-1):
            for j,flip in ((0,False),(cols-1,True)):
                a=i*cols+j; b=(i+1)*cols+j; q=(a,b,b+stride,a+stride)
                faces.append(q if (flip^(side_sign>0)) else tuple(reversed(q)))
        for i,flip in ((0,True),(len(rows_spec)-1,False)):
            for j in range(cols-1):
                a=i*cols+j; q=(a,a+1,a+1+stride,a+stride)
                faces.append(q if (flip^(side_sign>0)) else tuple(reversed(q)))
        api.surface(name,verts,faces,mat,driver,uv=uv)
        rim=[outer_grid[i][0] for i in range(len(rows_spec))]+[outer_grid[-1][j] for j in range(1,cols)]+[
            outer_grid[i][-1] for i in range(len(rows_spec)-2,-1,-1)]+[outer_grid[0][j] for j in range(cols-2,-1,-1)]
        api.tube(name+'FineBrassRim',rim,[.00155]*len(rim),rim_mat,driver,sides=7)
        if voronoi_veins:
            for idx,u_track in enumerate((-.42,.05,.44)):
                v_pts=[]
                for r_i in range(1,len(rows_spec)-1):
                    c_f=(u_track+.22*math.sin(r_i*1.1+idx*2.1)+1)*.5*(cols-1)
                    c0=max(0,min(cols-2,int(c_f))); frac=c_f-c0
                    p0,p1=outer_grid[r_i][c0],outer_grid[r_i][c0+1]
                    v_pts.append(tuple(p0[k]*(1-frac)+p1[k]*frac+(side_sign*.0004 if k==0 else 0) for k in range(3)))
                api.tube(name+'VoronoiCellRidge'+str(idx),v_pts,[.00055]*len(v_pts),'gold_light',driver,sides=5)

    belt_y_at=lambda x: -.058 + .010*(x/.13)
    for sign,label in [(-1,'L'),(1,'R')]:
        raw=[(sign*.070,.242),(sign*.072,.184),(sign*.082,.128),(sign*.066,.068),
             (sign*.060,.008),(sign*.068,belt_y_at(sign*.068))]
        front_h=[(x,y,api.fit_front(x,y,.0028)) for x,y in raw]
        over_shoulder=[(sign*.066,.225,.058),(sign*.068,.246,.012),front_h[0]]+front_h[1:]
        api.strap('ShoulderHarness'+label,over_shoulder,.013,'leather',thickness=.0028)
        buckle('ChestBuckle'+label,(sign*.072,.182,api.fit_front(sign*.072,.182,.0055)),.018,.021)
        side_ang=0.0 if sign>0 else math.pi
        rib_pts=[(sign*.078,.112,api.fit_front(sign*.078,.112,.003)),
                 api.fit_radial(side_ang+sign*.45,.110,.003),
                 api.fit_radial(side_ang,.112,.003),(sign*.052,.118,.072)]
        api.strap('RibTankStrap'+label,rib_pts,.011,'leather',thickness=.0024)
    sternum_pts=[(x,.176,api.fit_front(x,.176,.0032)) for x in (-.068,-.034,0.0,.034,.068)]
    api.strap('SternumCrossStrap',sternum_pts,.0115,'leather',thickness=.0025)
    buckle('SternumCenterBuckle',(0.0,.176,api.fit_front(0.0,.176,.0058)),.016,.018)

    belt_pts=[api.fit_radial(i/48*tau,belt_y_at(math.cos(i/48*tau)*.11),.0035) for i in range(49)]
    api.tube('WaistUtilityBelt',belt_pts,[.0075]*len(belt_pts),'leather','body',sides=8)
    buckle('WaistClasp',(0.0,belt_y_at(0),api.fit_front(0.0,belt_y_at(0),.008)),.028,.025)
    for kx in (-.032,.032):
        ky=belt_y_at(kx); box('BeltKeeper'+str(kx),(kx,ky,api.fit_front(kx,ky,.006)),(.008,.024,.012),'gold',bevel=.001)

    for sign,label,drv_leg in [(-1,'L','leg_l'),(1,'R','leg_r')]:
        by0=belt_y_at(sign*.088)
        sling=[(sign*.076,by0,api.fit_front(sign*.076,by0,.005)),(sign*.112,-.135,-.048),
               (sign*.124,-.205,-.022),(sign*.122,-.235,-.006)]
        s_obj=api.strap('HipSling'+label,sling,.0115,'leather_dark',thickness=.0025)
        s_obj['deform_mode']='hip_sling'
        buckle('HipSlingBuckle'+label,(sign*.112,-.138,-.052),.016,.020)
        thigh_loop=[(-sign*.002+.048*math.cos(j/36*tau),-.065,.052*math.sin(j/36*tau)) for j in range(37)]
        api.tube('ThighHarnessBand'+label,thigh_loop,[.0048]*37,'leather_dark',drv_leg,sides=6)
        buckle('ThighBandBuckle'+label,(sign*.012,-.065,-.053),.014,.017,driver=drv_leg)

    vx,vy,vz=-.136,-.138,-.036
    api.strap('SpecimenMountingBracket',[(-.116,belt_y_at(-.116),-.034),(vx,vy+.054,vz)],.012,'gold_light',thickness=.003)
    cylinder_domed('SpecimenCapTop',(vx,0,vz),.020,.020,vy+.036,vy+.054,'gold',segs=24,cap_rings=4)
    cylinder_domed('SpecimenStopperNozzle',(vx,0,vz),.009,.009,vy+.054,vy+.064,'gold_light',segs=16,cap_rings=3)
    cylinder_domed('SpecimenCapBottom',(vx,0,vz),.020,.020,vy-.054,vy-.036,'gold',segs=24,cap_rings=4)
    loop('SpecimenUpperCollarRing',(vx,0,vz),.0215,.0215,vy+.036,'gold_light',thickness=.0020,segs=28)
    loop('SpecimenLowerCollarRing',(vx,0,vz),.0215,.0215,vy-.036,'gold_light',thickness=.0020,segs=28)
    cylinder_domed('SpecimenVialGlass',(vx,0,vz),.0182,.0182,vy-.037,vy+.037,'glass',segs=28,cap_rings=2)
    for rod_i in range(3):
        ra=rod_i/3*tau+.4; rx_r,rz_r=vx+.0198*math.cos(ra),vz+.0198*math.sin(ra)
        api.tube('SpecimenTieRod'+str(rod_i),[(rx_r,vy-.038,rz_r),(rx_r,vy+.038,rz_r)],[.0011,.0011],'gold',sides=6)
    spec_core=[(vx+.003*math.sin(t*4),vy-.026+.052*t,vz+.003*math.cos(t*4)) for t in (0,.25,.5,.75,1.0)]
    api.tube('GoldenBioSpecimenCore',spec_core,[.0022,.0048,.0062,.0045,.0018],'specimen_gold',sides=10)
    for fr in (-1,1):
        frond=[(vx,vy-.004,vz),(vx+fr*.007,vy-.016,vz+fr*.004),(vx+fr*.009,vy-.028,vz-fr*.003)]
        api.tube('GoldenBioSpecimenFrond'+str(fr),frond,[.0024,.0016,.0007],'specimen_gold',sides=7)

    box('RightBeltUtilityPouch',(.106,belt_y_at(.106)-.006,-.052),(.036,.042,.024),'leather',bevel=.004)
    box('RightBeltPouchFlap',(.106,belt_y_at(.106)+.008,-.062),(.038,.018,.007),'leather',bevel=.002)
    api.ellipsoid('RightBeltPouchButton',(.106,belt_y_at(.106)-.002,-.066),(.0035,.0035,.002),'gold',segments=12,rings=8)
    box('LeftRearBeltPouch',(-.096,belt_y_at(-.096)-.008,.062),(.038,.044,.024),'leather',bevel=.004)
    box('LeftRearBeltFlap',(-.096,belt_y_at(-.096)+.008,.072),(.040,.018,.007),'leather',bevel=.002)
    box('LeftThighUtilityPouch',(-.048,-.052,.018),(.028,.068,.044),'leather',driver='leg_l',bevel=.005)
    box('LeftThighPouchFlap',(-.052,-.025,.018),(.031,.022,.046),'leather',driver='leg_l',bevel=.0025)
    api.ellipsoid('LeftThighPouchStud',(-.068,-.036,.018),(.0022,.004,.004),'gold',driver='leg_l',segments=12,rings=8)
    box('RightThighKnifeSheath',(.047,-.058,-.004),(.018,.082,.028),'leather_dark',driver='leg_r',bevel=.004)
    box('RightKnifeThroatCollar',(.048,-.016,-.004),(.021,.011,.031),'gold',driver='leg_r',bevel=.002)
    box('RightKnifeGrip',(.048,.004,-.004),(.013,.030,.020),'rubber',driver='leg_r',bevel=.003)
    api.tube('RightKnifePommel',[(.048,.024+.0085*math.cos(j/16*tau),-.004+.0085*math.sin(j/16*tau)) for j in range(17)],[.0020]*17,'gold_light','leg_r',sides=7)

    box('DorsalTankBackplate',(0.0,.135,.074),(.118,.185,.012),'rubber',bevel=.003)
    for sign in (-1,1):
        tx,tz=sign*.043,.108
        cylinder_domed('OxygenCylinder'+str(sign),(tx,0,tz),.033,.033,.042,.222,'ivory',segs=28,cap_rings=5)
        for by in (.074,.192):
            loop('TankBrassBand'+str(sign)+str(by),(tx,0,tz),.035,.035,by,'gold',thickness=.0042,segs=28)
        api.tube('TankValveStem'+str(sign),[(tx,.248,tz),(tx,.268,tz)],[.0055,.0055],'gold',sides=10)
        loop('TankValveCollar'+str(sign),(tx,0,tz),.009,.009,.254,'gold_light',thickness=.0022,segs=16)
        hose_ctrl=[(tx,.266,tz),(sign*.078,.288,.092),(sign*.112,.284,.044),
                   (sign*.108,.264,-.008),(sign*.072,.252,-.030),(sign*.048,.252,-.012)]
        dense_h=[]
        for idx in range(len(hose_ctrl)-1):
            p0=hose_ctrl[max(0,idx-1)]; p1=hose_ctrl[idx]; p2=hose_ctrl[idx+1]; p3=hose_ctrl[min(len(hose_ctrl)-1,idx+2)]
            for s_i in range(12):
                t=s_i/12
                dense_h.append(tuple(.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t**3)
                                     for a,b,c,d in zip(p0,p1,p2,p3)))
        dense_h.append(hose_ctrl[-1])
        radii_h=[.0088+.0017*math.sin(k*math.pi) for k in range(len(dense_h))]
        h_obj=api.tube('CorrugatedShoulderHose'+str(sign),dense_h,radii_h,'rubber','body',sides=10)
        h_obj['deform_mode']='hose_bridge'
        loop('HoseBrassFittingTank'+str(sign),(tx,0,tz),.0095,.0095,.266,'gold',thickness=.0022,segs=16)
    api.tube('TankManifoldBridge',[(-.043,.260,.108),(.043,.260,.108)],[.0048,.0048],'gold',sides=8)
    box('TankBandCenterBridge',(0.0,.133,.108),(.024,.135,.014),'gold',bevel=.002)

    for side,side_sign in [('l',-1),('r',1)]:
        wrapped_armor_plate('LeafShoulderArmor','arm_'+side,side_sign,[
            (.042,-side_sign*.062,.003,.024,.025,.65,.000),
            (.025,-side_sign*.054,.003,.036,.035,1.08,.002),
            (-.006,-side_sign*.045,.002,.040,.039,1.24,.004),
            (-.042,-side_sign*.038,.002,.039,.039,1.18,.006),
            (-.074,-side_sign*.032,.001,.037,.037,.96,.009),
            (-.098,-side_sign*.028,.001,.034,.034,.48,.004),
        ],mat='armor',rim_mat='gold_light',voronoi_veins=True,thick=.004)

        wrapped_armor_plate('FittedForearmBracer','forearm_'+side,side_sign,[
            (-.012,0.0,.001,.028,.028,.36,.000),
            (-.042,side_sign*.001,.000,.031,.030,.92,.003),
            (-.088,side_sign*.002,-.001,.030,.029,1.05,.003),
            (-.140,side_sign*.003,-.002,.026,.025,.96,.002),
            (-.182,side_sign*.004,-.003,.023,.022,.82,.001),
            (-.200,side_sign*.004,-.003,.022,.021,.55,.000),
        ],mat='armor',rim_mat='gold_light',voronoi_veins=True,thick=.0032)

        loop('WristLeatherSeal',(side_sign*.004,0,-.004),.022,.021,-.207,'leather_dark','forearm_'+side,.0038,segs=28)
        loop('WristBrassClasp',(side_sign*.004,0,-.004),.023,.022,-.213,'gold','forearm_'+side,.0016,segs=28)
        api.ellipsoid('WristGaugeHousing',(side_sign*.025,-.206,-.004),(.004,.011,.011),'gold','forearm_'+side,segments=18,rings=10)
        api.ellipsoid('WristGaugeDial',(side_sign*.028,-.206,-.004),(.002,.008,.008),'gauge','forearm_'+side,segments=16,rings=8)

        kn_levels=[(.042,.010,-.028),(.022,.024,-.032),(.000,.028,-.033),(-.024,.024,-.031),(-.046,.010,-.028)]
        kn_v=[]; kn_f=[]; kn_uv=[]; kn_c=13; kn_grid=[]
        for sh in (0,1):
            dz=.003 if sh else 0.0
            for r_i,(ky,kw,kz) in enumerate(kn_levels):
                row_p=[]
                for j in range(kn_c):
                    u=j/(kn_c-1)*2-1; px=side_sign*.002+u*kw; pz=kz+.010*u*u+dz
                    kn_v.append((px,ky,pz)); kn_uv.append(((u+1)*.5,r_i/(len(kn_levels)-1)))
                    if sh==0:row_p.append((px,ky,pz))
                if sh==0:kn_grid.append(row_p)
        kn_st=len(kn_levels)*kn_c
        for sh in (0,1):
            for i in range(len(kn_levels)-1):
                for j in range(kn_c-1):
                    k=sh*kn_st+i*kn_c+j
                    kn_f.append((k,k+1,k+kn_c+1,k+kn_c) if sh==0 else (k+kn_c,k+kn_c+1,k+1,k))
        for i in range(len(kn_levels)-1):
            for j in (0,kn_c-1):
                a=i*kn_c+j; b=(i+1)*kn_c+j; kn_f.append((a,b,b+kn_st,a+kn_st))
        for i in (0,len(kn_levels)-1):
            for j in range(kn_c-1):
                a=i*kn_c+j; kn_f.append((a,a+1,a+1+kn_st,a+kn_st))
        api.surface('ContouredKneeProtection',kn_v,kn_f,'rubber','calf_'+side,uv=kn_uv)
        kn_rim=[kn_grid[i][0] for i in range(len(kn_levels))]+[kn_grid[-1][j] for j in range(1,kn_c)]+[
            kn_grid[i][-1] for i in range(len(kn_levels)-2,-1,-1)]+[kn_grid[0][j] for j in range(kn_c-2,-1,-1)]
        api.tube('KneeProtectionGoldRim',kn_rim,[.0014]*len(kn_rim),'gold_light','calf_'+side,sides=7)

        boot_sec=[
            (-.078,0.0,-.060,.018,.019,.015),
            (-.064,0.0,-.040,.024,.027,.023),
            (-.042,0.0,-.012,.028,.032,.042),
            (-.014,0.0,.002,.026,.028,.032),
            (.018,0.0,.001,.025,.026,.027),
            (.048,0.0,.000,.026,.027,.028),
        ]
        b_verts=[]; b_uv=[]; b_faces=[]; b_sides=28
        for r_i,(by,bcx,bcz,brx,bfront,bback) in enumerate(boot_sec):
            for j in range(b_sides):
                phi=j/b_sides*tau; s,c=math.sin(phi),math.cos(phi)
                v_dip=-.012*max(0.0,c)**3 if r_i>=4 else 0.0
                b_verts.append((bcx+brx*s,by+v_dip,bcz+(-bfront*c if c>0 else -bback*c)))
                b_uv.append((j/b_sides,r_i/(len(boot_sec)-1)))
        for r_i in range(len(boot_sec)-1):
            for j in range(b_sides):
                j1=(j+1)%b_sides; p=r_i*b_sides+j; q=r_i*b_sides+j1
                b_faces.append((p,q,q+b_sides,p+b_sides))
        for last,idx_r in ((False,0),(True,len(boot_sec)-1)):
            by,bcx,bcz,_,_,_=boot_sec[idx_r]
            cc=len(b_verts); b_verts.append((bcx,by,bcz)); b_uv.append((.5,.5))
            for j in range(b_sides):
                p=idx_r*b_sides+j; q=idx_r*b_sides+(j+1)%b_sides
                b_faces.append((cc,p,q) if last else (cc,q,p))
        boot_obj=api.surface('StructuredDiveBoot',b_verts,b_faces,'rubber','fin_'+side,uv=b_uv)
        boot_obj['deform_mode']='boot_cuff'
        cuff_pts=[b_verts[(len(boot_sec)-1)*b_sides+(j%b_sides)] for j in range(b_sides+1)]
        cuff_obj=api.tube('BootFlaredVCuff',[(x*1.04,y,z*1.04) for x,y,z in cuff_pts],[.0038]*len(cuff_pts),'gold_light','fin_'+side,sides=7)
        cuff_obj['deform_mode']='boot_cuff'
        ankle_strap=[(.027*math.sin(j/28*tau),.012,-.029*math.cos(j/28*tau) if math.cos(j/28*tau)>0 else -.031*math.cos(j/28*tau)) for j in range(29)]
        api.tube('BootUpperAnkleStrap',ankle_strap,[.0032]*len(ankle_strap),'leather_dark','fin_'+side,sides=6)
        buck_ring=[(side_sign*.028,.012+.009*math.cos(j/18*tau),.002+.009*math.sin(j/18*tau)) for j in range(19)]
        api.tube('BootOuterAnkleRingBuckle',buck_ring,[.0016]*19,'gold','fin_'+side,sides=6)
        heel_band=[(0.0,-.044,.043),(side_sign*.028,-.032,.015),(0.0,-.032,-.030),(-side_sign*.028,-.032,.015),(0.0,-.044,.043)]
        api.tube('BootHeelCounterBand',heel_band,[.0032]*5,'gold_light','fin_'+side,sides=6)
        fore_strap=[(.026*math.sin(j/24*tau),-.058,-.036-.028*math.cos(j/24*tau)) for j in range(25)]
        api.tube('BootForefootStrap',fore_strap,[.0030]*25,'leather_dark','fin_'+side,sides=6)
        buckle('BootInstepBuckle',(0.0,-.056,-.066),.014,.012,driver='fin_'+side)

        def fin_spine(t):
            return (-.074 - .304*t + .040*(t**2.2), -.056 - .138*t - .094*(t**1.72))

        for lobe in (-1,1):
            rows_f=24; cols_f=12; f_verts=[]; f_uv=[]; f_faces=[]
            outer_rail_pts=[]; spine_rib_pts=[]
            for i in range(rows_f):
                t=i/(rows_f-1); fy,fz=fin_spine(t)
                x_outer=.024 + .056*(math.sin(t*math.pi*.76)**.78) - .010*(t**3)
                x_inner=0.0 if t<=.40 else .002 + .066*(((t-.40)/.60)**1.35)
                x_outer=max(x_inner+.0018,x_outer)
                mid_x=.5*(x_inner+x_outer); half_w=.5*(x_outer-x_inner); thick_f=.0092*(1-.74*t)
                for j in range(cols_f):
                    ang=j/(cols_f-1)*tau; ca,sa=math.cos(ang),math.sin(ang)
                    lx=lobe*(mid_x + half_w*ca)
                    camber=.0065*math.sin(t*math.pi)*(1-ca*ca*.4)
                    ly=fy + (thick_f*sa + camber)*.58
                    lz=fz + (thick_f*sa + camber)*(-.81)
                    f_verts.append((lx,ly,lz))
                    u_tex=.5*(1-ca) if t>.40 else (x_outer-abs(lx))/max(.01,x_outer)
                    f_uv.append((max(0.0,min(1.0,u_tex)),t))
                outer_rail_pts.append((lobe*x_outer,fy+.004,fz-.005))
                if t<=.90:
                    spine_rib_pts.append((lobe*(.010+.036*t),fy+.0065*(1-.6*t),fz-.0085*(1-.6*t)))
            for i in range(rows_f-1):
                for j in range(cols_f-1):
                    a=i*cols_f+j; b=i*cols_f+j+1; q=(a,b,b+cols_f,a+cols_f)
                    f_faces.append(q if lobe>0 else tuple(reversed(q)))
            for cap_end,row_idx in ((False,0),(True,rows_f-1)):
                cx_c=sum(f_verts[row_idx*cols_f+j][0] for j in range(cols_f))/cols_f
                cy_c=sum(f_verts[row_idx*cols_f+j][1] for j in range(cols_f))/cols_f
                cz_c=sum(f_verts[row_idx*cols_f+j][2] for j in range(cols_f))/cols_f
                ci=len(f_verts); f_verts.append((cx_c,cy_c,cz_c)); f_uv.append((.2,1.0 if cap_end else 0.0))
                for j in range(cols_f-1):
                    p=row_idx*cols_f+j; q=p+1
                    f_faces.append((ci,p,q) if (cap_end^(lobe<0)) else (ci,q,p))
            api.surface('SwallowtailBioFinBlade'+str(lobe),f_verts,f_faces,'fin_ivory','fin_'+side,uv=f_uv)
            api.tube('FinOuterAmberRail'+str(lobe),outer_rail_pts,
                     [.0036*(1-.58*i/(rows_f-1)) for i in range(rows_f)],'gold','fin_'+side,sides=7)
            api.tube('FinLongitudinalRib'+str(lobe),spine_rib_pts,
                     [.0028*(1-.68*i/max(1,len(spine_rib_pts)-1)) for i in range(len(spine_rib_pts))],'gold_light','fin_'+side,sides=6)
        v_shroud=[(-.024,-.068,-.048),(0.0,-.082,-.072),(.024,-.068,-.048)]
        api.tube('FinBootDorsalVKeel',v_shroud,[.0036,.0048,.0036],'gold_light','fin_'+side,sides=7)
