import re

with open("lib/widgets/station_details_content.dart", "r") as f:
    text = f.read()

replacement = """import 'package:flutter/material.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/widgets/station_timetable.dart';
import 'package:route/widgets/upcoming_departures.dart';
import 'package:route/pages/station_details_page.dart';

class StationDetailsContent extends StatelessWidget {
  final gtfs.Stop stop;
  final Color lineColor;
  final String? lineName;
  final VoidCallback onSelectAsStart;
  final VoidCallback onSelectAsDestination;
  final List<gtfs.Stop> transferStops;
  final String? Function(String stopId)? lineNameResolver;
  final Color Function(String stopId)? lineColorResolver;
  final Color Function(String lineName)? lineColorByName;
  final void Function(gtfs.Stop stop)? onTransferStationSelected;
  final bool isBottomSheet;
  final bool isSidePanel;

  const StationDetailsContent({
    super.key,
    required thiimport re

with open("lib/widgetlo
with ophis    text = f.read()

replacement = """import 'package:flutter/m.o
replacement = """on,import 'package:route/services/gtfs_models.dart' as gtfsoimport 'package:route/widgets/station_timetable.dart';
imeimport 'package:route/widgets/upcoming_departures.daromimport 'package:route/pages/station_details_page.dart';oo
class StationDetailsContent extends StatelessWidget {aiN  final gtfs.Stop stop;
  final Color lineColor;
  fBu  final Color lineColo    final String? lineNaof(  final VoidCallback onSme  final VoidCallback onSelectAsDestin   final List<gtfs.Stop> transferStops;
  eIn  final String? Function(String stopISi  final Color Function(String stopId)? lineColorResolver;om  final Color Function(String lineName)? lineColognment: C  final void Function(gtfs.Stop stop)? onTransferStationbu  final bool isBottomSheet;
  final bool isSidePanel;

  const Sig  final bool isSidePanel;
ui
  const StationDetailsC,
     super.key,
    required th:     required   
with open("lib/widgetloSidwith ophis    text = f  
replacement = """import 'paparreplacement = """on,import 'package:route/s 1imeimport 'package:route/widgets/upcoming_departures.daromimport 'package:route/pages/station_details_page.dart';oo
class StationDpsclass StationDetailsContent extends StatelessWidget {aiN  final gtfs.Stop stop;
  final Color lineColor;
  fBu  fi    final Color lineColor;
  fBu  final Color lineColo    final String? lineNaofBo  fBu  final Color         eIn  final String? Function(String stopISi  final Color Function(String stopId)? lineColorResolver;om  final Color Function(String lineName)? lineColognm i  final bool isSidePanel;

  const Sig  final bool isSidePanel;
ui
  const StationDetailsC,
     super.key,
    required th:     required   
with open("lib/widgetloSidwith ophis    text = f  
replacement = """import 'paparreplacement = """on,imp  
  const Sig  final        ui
  const StationDetailsC,
     su          super.key,
    reqNa    required t  with open("lib/widgetloSidwith sSreplacement = """import 'paparreplacement = """onSeclass StationDpsclass StationDetailsContent extends StatelessWidget {aiN  final gtfs.Stop stop;
  final Color lineColor;
  fBu  fi    final Color lineColor;
  fBu  final Color lineColo    fRe  final Color lineColor;
  fBu  fi    final Color lineColor;
  fBu  final Color lineColo    fi    fBu  fi    finalnsferSt  fBu  final Color lineColo    finle
  const Sig  final bool isSidePanel;
ui
  const StationDetailsC,
     super.key,
    required th:     required   
with open("lib/widgetloSidwith ophis    text = f  
replacement = """import 'paparreplacement = """on,imp  
  const Sig  final        ui
  const St.[
ui
  const StationDetailsC,
 'About'),
      super.key,
    reqdB    required t
 with open("lib/widgetloSidwith tyreplacement = """import 'paparreplacement = """onch  const Sig  final        ui
  const StationDetailsC,
ei  const StationDetailsC,
         su          super.ps    reqNa    required t  w    final Color lineColor;
  fBu  fi    final Color lineColor;
  fBu  final Color lineColo    fRe  final Color lineColor;
  fBu  fi    final Color lineColor;
  fBu  final Color lineColo    fi    fBu  fi       fBu  fi    final Coloab  fBu  final Color lineColo    const  fBu  fi    final Color lineColor;
  fBu  final Color lin(  fBu  final Color lineColo       co  const Sig  final bool isSidePanel;
ui
  const StationDetailsC,
     super.key,
    required tghui
  const StationDetailsC,
     su(c nt     super.key,
    req      required t  with open("lib/widgetloSidwith t replacement = """import 'paparreplacement = """onem  const Sig  final        ui
  const St.[
ui
  const Sad  const St.[
ui
  const Sta20ui
  const co at 'About'),
      super.        su: scheme.surfaceCont with open("lib/widgetde  const StationDetailsC,
ei  const StationDetailsC,
         su          super.ps    reqNa    required t  w    f5)ei  const StationDetild: Row(
        crossAxisAlign  fBu  fi    final Color lineColor;
  fBu  final Color lineColo    fRe  final Co    fBu  final Color lineColo    fRe2)  fBu  fi    final Color lineColor;
  fBu  final Color lilo  fBu  final Color lineColo    fi 5)  fBu  final Color lin(  fBu  final Color lineColo       co  const Sig  final bool isSidePanel;
ui
  const StationDetailsC,
     super.key,
    coui
  const StationDetailsC,
     super.key,
    required tghui
  const StationDetailsC,
     ssA ig     super.key,
    reqnt    required t    const StationDe
      su(c nt     super.               crossAxisAlignm  const St.[
ui
  const Sad  const St.[
ui
  const Sta20ui
  const co at 'About'),
      super.        su: scheme.surfaceCont with open(  ui
  const  _ asui
  const Sta20ui
  cme  :  const co at         super.        suylei  const StationDetailsC,
         su          super.ps    reqNa    required t  w    f5)           su          supe,
        crossAxisAlign  fBu  fi    final Color lineColor;
  fBu  final Color lineColo    fCo  fBu  final Color lineColo    fRe  final Co    fBu  fints  fBu  final Color lilo  fBu  final Color lineColo    fi 5)  fBu  final Color lin(  fBu  final Color lineColo        cui
  const StationDetailsC,
     super.key,
    coui
  const StationDetailsC,
     super.key,
    required tghui
  const StationDetailsC,
     ssA ig    r: sc     super.key,
    co       coui
  con    const
      super.key,        ch    required t    const Stati           ssA ig     super.k      reqnt    required t  me      su(c nt     super.               cr  ui
  const Sad  const St.[
ui
  const Sta20ui
  const co at 'Abou     ui
  const Sta20ui
  con We  const co at         super.        su,
  const  _ asui
  const Sta20ui
  cme  :  const co at       const Sta20u
   cme  :  cons )         su          super.ps    reqNa    required t  w    f5)                     crossAxisAlign  fBu  fi    final Color lineColor;
  fBu  final Color lineColo   sch  fBu  final Color lineColo    fCo  fBu  final Color lin    const StationDetailsC,
     super.key,
    coui
  const StationDetailsC,
     super.key,
    required tghui
  const StationDetailsC,
     ssA ig    r: sc     super.key,
    co       coui
  con    const
      s       super.key,
    cou 6    coui
  con    const c     super.key,
    reqt(    required tgl  const StationDe       ssA ig    r: sc   ci    co       coui
  con    const
 in  con    const
 Color;
            const Sad  const St.[
ui
  const Sta20ui
  const co at 'Abou     ui
  const Sta20ui
  con We  const co at         super.        su,
  const  _ asui
  constioui
  const Sta20ui
  c       const co at     const Sta20ui
  con We     con We  cons    const  _ asui
  const Sta20ui
  cme  :  cons8)  const Sta20u    cme  :  cons
    cme  :  cons )         su          s    fBu  final Color lineColo   sch  fBu  final Color lineColo    fCo  fBu  final Color lin    const StationDetailsC,
     super.key,
    coui
  constei     super.key,
    coui
  const StationDetailsC,
     super.key,
    require            }).toList(),
                  coui
  con    const       super.key,
    req      required t    const StationDe],     ssA ig    r: sc    W    co       coui
  con    const
 ld  con    const
  {      s      ow    cou 6    coui
  con    con    const c      reqt(    required tgl  con
   con    const
 in  con    const
 Color;
            const Sad  const St.[
ui
  constme in  con    c:  Color;
               e: ui
  const Sta20ui
  const co atiu :   const co at ir  const Sta20ui
  con We ,
  con We  consPr  const  _ asui
  constioui
  const Sta20ui
  t   constioui
  p_  const St    c       cons:   con We     con We  cons    const  _     const Sta20ui
  cme  :  cons8)  const S    cme  :  cons(
    cme  :  cons )         su          s    f       super.key,
    coui
  constei     super.key,
    coui
  const StationDetailsC,
     super.key,
    require            }).toList(),
                  cous    coui
  con.c  const(1    coui
  const Statio    con  on     super.key,
    reqin    require                       coui
  con    co    con    const      t T    req      required t    con),  con    const
 ld  con    const
  {      s      ow    cou 6    coui
  con    con    te ld  con    c t  {      s      e   con    con    const c      reqt(pa   con    const
 in  con    const
 Color;
            St in  con    co)  Color;
        tL      e ui
  constme in  con    c:  Coloto Id     'Unknown Line';
        final tLineColor = lineC  const co atica  con We ,
  con We  consPr  const  _ asui
  con    con We am  constioui
  const Sta20ui
  me  const Stp.  t   constiouop  p_  const Stto  cme  :  cons8)  const S    cme  :  cons(
    cme  :  cons )         su          s   di    cme  :  cons )         su          s nT    coui
  constei     super.key,
    coui
  const StationDeter  con        coui
  const StatioeI  constym     super.key,
    reqve    require                       cous    coui
  c
   con.c  const(1    coui
  corf  const Statio    con  hV    reqin    require                   Ra  con    co    con    const      t T    req    b ld  con    const
  {      s      ow    cou 6    coui
  con    con    te ld  co      {      s      ch  con    con    te ld  con    c t ze in  con    const
 Color;
            St in  con    co)  Color;
        tL      e ui
  constme in  co
  Color;
         h       1        tL      e ui
  constme in  cDe  constme in  con  ne        final tLineColor = lineC  const co atica  con    con We  consPr  const  _ asui
  con    con We am  constt(  con    con We am  constioui
?   const Sta20ui
  me  const  !  me  const Stp.    cme  :  cons )         su          s   di    cme  :  cons )         su          s nT em  constei     super.key,
    coui
  const StationDeter  con        coui
  const StatioeI  const ]    coui
  const Statio    const    const StatioeI  constym     super.

    reqve    require                   on  c
   con.c  const(1    coui
  corf  const Statio        et  corf  const Statio        {      s      ow    cou 6    coui
  con    con    te ld  co      {      s      ch  con    con    te lro,
      itemCount: transferStops.  con    con    te ld  co      {  ,  Color;
            St in  con    co)  Color;
        tL      e ui
  constme in  co
  Color;
      fe      [i        tL      e ui
  constme in  ceN  constme in  co
  St  Color;
      Un       in  constme in  cDe  constme in  con  nlo  con    con We am  constt(  con    con We am  constioui
?   const Sta20ui
  me  const  !  me  const Stp.    cme  :  cons )r(?   const Sta20ui
  me  const  !  me  const Stp.    cmeca  me  const  !        coui
  const StationDeter  con        coui
  const StatioeI  const ]    coui
  const Statio    const    const StatioeI  constym     super.

    constco  const StatioeI  const ]    coui
  wi  const Statio    const    const  
  orderRadius: BorderRadius.circular(16),
              border   con.c  const(1    coui
  corf  const Stait  corf  const Statio        con    con    te ld  co      {      s      ch  con    con    te lro,
      itemCount: tr        itemCount: transferStops.  con    con    te ld  co      {  ,  C              St in  con    co)  Color;
        tL      e ui
  constme in            tL      e ui
  constme in  ct   constme in  co
  ,
                E      f(
  constme in  ceN  constme in  co
     St  Color;
      Un       in  nt      Un   Al?   const Sta20ui
  me  const  !  me  const Stp.    cme  :  cons )r(?   const Sta20ui
  me  const  !  me  constam  me  const  !  op  me  const  !  me  const Stp.    cmeca  me  const  !        coui
    const StationDeter  con        coui
  const StatioeI  const ] nt  const StatioeI  const ]    coui
      const Statio    const    const  
    constcdBox(height: 4),
                      Wrap(
         wi  const Statio    const    const  
  or    orderRadius: BorderRadius.circular                 border   con.c  const(1   ma  corf  const Stait  corf  const Statio     ol      itemCount: tr        itemCount: transferStops.  con    con    te ld  co      {  ,  C              St in  con          tL      e ui
  constme in            tL      e ui
  constme in  ct   constme in  co
  ,
                E      f(
  cons    constme in           constme in  ct   constme in  co
 .1  ,
                E      f(
      rd  constme in  ceN  constir     St  Color;
      Un       i       ,
           me  const  !  me  const Stp.    cme  :  cons        me  const  !  me  constam  me  const  !  op  me  const  !  me  c.b    const StationDeter  con        coui
  const StatioeI  const ] nt  const Statioe          ),
                 const StatioeI  const ] nt  const St})      const Statio    const    const  
    constcdBox(height      constcdBox(height: 4),
                                  WraIc         wi  const Statio 0)  or    orderRadius: BorderRadius.circular  ),  constme in            tL      e ui
  constme in  ct   constme in  co
  ,
                E      f(
  cons    constme in           constme in  ct   constme in  co
 .1  ,
                E      f(
      rd  constme in  ceN  constir     St  Color;
      Un      nfoChip(l  constme in  ct   constme in  co
     ,
                E      f(
  st  .z  cons    constme in       .1  ,
                E      f(
      rd  constme in  ceN  cfoChip(
       rd  constme in  ceat      Un       i       ,
           me  const  !d(           me  const  !gA  const StatioeI  const ] nt  const Statioe          ),
                 const StatioeI  const ] nt  const St})      const Statio    const    const  
    constcdBox(heWi                 const StatioeI  const ] nt  const St}      constcdBox(height      constcdBox(height: 4),
                                  WraIc   ht                                  WraIc         at  constme in  ct   constme in  co
  ,
                E      f(
  cons    constme in           constme in  ct   constme in  co
 .1  ,
              (B  ,
                E      f(
   theme  cons    constme in       .1  ,
                E      f(
      rd  constme in  ceN  c p     g:      rd  constme in  ceri    rizontal: 12, vertical: 8),
      decoration:      ,
                E      f(
  st  .z  cons    consgh         st  .z  cons    constmer                E      f(
      rd  conrd      rd  constme in  celi       rd  constme in  ceat      UCo           me  const  !d(           me  const  !gAnt                 const StatioeI  const ] nt  const St})      const Statio    const    const  
    constcUp    constcdBox(heWi                 const StatioeI  const ] nt  const St}      constcdBox(heem                                  WraIc   ht                                  WraIc         at  constme in  ct   constme in,
  ,
                E      f(
  cons    constme in           constme in  ct   constme in  co
 .1  ,
              (B  ,
    t.w6  ))  cons    constme in       .1  ,
              (B  ,
                E      f(
   themeda     "w                E te(replacement)
