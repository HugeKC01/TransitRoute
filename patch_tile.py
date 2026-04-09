import sys

with open('lib/main.dart', 'r') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if "Widget _buildSearchSuggestionTile(gtfs.Stop stop, VoidCallback onTap) {" in line:
        start_idx = i
    if "  Widget _buildWideDirectionSearchResults(BuildContext context) {" in line and start_idx != -1:
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_code = """  Widget _buildSearchSuggestionTile(gtfs.Stop stop, VoidCallback onTap) {
    final theme = Theme.of(context);
    final lineColor = _getLineColor(stop.stopId);
    final int serviceType = _getServicePriority(stop);
    final lineName = _getLineName(stop.stopId) ?? '';

    IconData getIconForType(int type) {
      switch (type) {
        case 1:
          return Icons.subway;
        case 2:
          return Icons.train;
        case 3:
          return Icons.directions_bus;
        case 4:
          return Icons.directions_boat;
        defimport sys

with open('libns.d
wittions_tr    lines = f.readlines()

starn Paddi
start_idx = -1
end_idx  Edend_idx = -1
et
ic(horizontal    if "Widget _buildSearchSu chi        start_idx = i
    if "  Widget _buildWideDirectionSearchResults(BuildContext con
     if   color: theme.        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_code = """  Widget _           breonTap,
  
if st    child    new_code = """  Widget _buildSeans    final theme = Theme.of(context);
    final lineColor = _getLineColor(stop.stopId);
         final lineColor = _getLineColo: R    final int serviceType = _getServicePriorit        final lineName = _getLineName(stop.stopId) ?? '';  
    IconData getIconForType(int type) {
                    switch (type) {
        c                 case 1teIcon =          retu(l        case 2:
                  
                    case 3:
          rnul   & routeIcon.i        case 4:
                     re          retu          defimport sys

with Size: MainAx
wiize.min,
           wittions_tr    liil
starn Paddi
start_idx = -1         Costainer(
   end            et
ic(horizontal    if
 i      if "  Widget _buildWideDirectionSearchResults(BuildContext           if   color: theme.        end_idx = i
        break

if starec        break

if start_idx != -1 and en   
if          co    new_code = """  Widget _        5)  
if st    child    new_code = """  WidgetxShapeici    final lineColor = _getLineColor(stop.stopId);
         final lineColor = _getLiure.as         final lineColor = _getLineColo: RIcon,
      IconData getIconForType(int type) {
                    switch (type) {
        c                 case 1teIcon =          retu(l        case 2),                    switch (type) {
  co        c                 sNotEmpty)                  
                    case 3:
          rnul   & rout                               rnul   & routeIc                       re          retu      ymm
with Size: MainAx
wiize.min,
           wittions_tr    lii   wiize.min,
                 vstarn Paddi
start_idx = -1     sta            end            et
ic(          ic(horiation: BoxDeco i ion(
                    break

if starec        break

if start_idx != -1 and en   
if          co    new_code = """  Widget _   
 
if starec     
if start_idx != -1 a   if          co    new_code chif st    child    new_code = """  WidgetxShapetop.code!         final lineColor = _getLiure.as         final lineColor = _getLineColo: RIcon,
      Icon(l      IconData getIconForType(int type) {
                    switch (type) {
       la                    switch (type) {
              c                 case 1te    co        c                 sNotEmpty)                  
                    case 3:
          rnul   &                       case 3:
          rnul   & rout                  rnul   & rout     with Size: MainAx
wiize.min,
           wittions_tr    lii   wiize.min,
                 vstarn Paddi
start_idx = -1 }
wiize.min,
                rn                 vstarn Paddi
start_idx =ngstart_idx = -1     sta      (
ic(          ic(horiation: BoxDeco i ion(
                              break

if starec      
if star   ),
             
if start_idx != -1on: Bif          co    new_code    
if starec     
if start_idx != -1 a   if      if start_idxrRa      Icon(l      IconData getIconForType(int type) {
                    switch (type) {
       la                    switch (type) {
              c                 case 1te    co        c                        switch (type) {
       la                la                    switc),              c                 case 1te   Co                    case 3:
          rnul   &                       case 3:
          rnul   & rou            rnul   &        te          rnul   & rout                  rnul    wiize.min,
           wittions_tr    lii   wiize.min,
                 vst&&    p.code!.                 vstarn Paddi
start_idx =  start_idx = -1 }
wiize.min,
,
wii                         start_idx =ngstart_idx = -1     sta      (
iccodic(          ic(horiation: BoxDeco i ion(:                               break

if   
if starec      
if starputeLuminanceif st0.5)
                   if            if starec     
if start_idx != -1 a   if      if st   if    : Colors.                    switch (type) {
       la                    switch (type) {
              c           la                          )              c                 case 1te            la                la                    switc),              c                 cas},
             rnul   &                       case 3:
          rnul   & rou            rnul   &        te          rnul   & rout 
           rnul   & rou            rnul   &     xi           wittions_tr    lii   wiize.min,
                 vst&&    p.code!.                 vstarn Paddi
staop                 vst&&    p.code!.    : constart_idx =  start_idx = -1 }
wiize.min,
,
wii                  wiize.min,
,
wii    fontWeight: FontWeight.iccodic(          ic(horiation: BoxDeco i ion(:                        
if   
if starec      
if starputeLuminanceif st0.5)
                   if        ameif sNoif pty) ...[
                      if  const Sif start_idx != -1 a   if      if st   if     Te       la                    switch (type) {
              c           la               ty              c           la                1             rnul   &                       case 3:
          rnul   & rou            rnul   &        te          rnul   & rout 
           rnul   & rou            rnul   &     xi                       rnul   & rou            rnul   ,
                    rnul   & rou            rnul   &     xi           wittions_tr                      vst&&    p.code!.                 vstarn Paddi
staop                 vst&&ewstaop                 vst&&    p.code!.    : constart_i  f.writewiize.min,
,
wii                  wiize.min,
,
wii    fontWeight: FontWeighd i,
wiis")
