with open('lib/main.dart', 'r') as f:
    text = f.read()

# remove old if block
pattern1 = """  @override
  Widget build(Buildontext context) {
    if (!_isGtfsDataLoaded) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: widget.currentAccentColor),
              const SizedBox(height: 24),
              Text(
                'Loading Transit Data...',
                style: GoogleFonts.googleSans(
                  textStyle: TextStyle(
                    color: widget.currentAccentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);"""

replacement1 = """  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);"""
with open('lib/main.dart', 'r r    text = f.read()

# remack
pattern2
# remove old if b Scpattern1 = """  @ovend  Widget build(BuildContgr    if (!_isGtfsDataLoadedme.surface,
       return Scaffold(
     &         body: Center(nt    """      child: St            mainAxisAli[
            children: [
              CircularProgressI               ndColor: th              const SizedBox(height: 24),
              Text(
          tex              Text(
                'Loa

                'L S                style: GoogleFonts.googleon                  textStyle: TextStyle(
      _                    color: widget.currl,                    fontSize: 16,
                  bo                    fontWeight: t                   ),
                ),
       ar                ),
:     ,
          ),
          if (!_i    sDataLoaded                 tainer(         
     c
replacement1 = """  @override
  Widge     Widget build(Build
                child: Column(
                 with open('lib/main.dart', 'r r    texce
# remack
pattern2
# remove old if b Scpa           patterncu# removre       return Scaffold(
     &         body: Center(nt    """      child: St            mainAxisAli[
          &         body: C              children: [
              CircularProgressI               ndColFo              Circul                  Text(
          tex              Text(
                'Loa

                'L S  
                                     'Loa

           
                'Lght      _                    color: widget.currl,                    fontSize: 16,
                  bo                    bo                    fontWeight: t                   ),
     )                ),
       ar                ),
:     ,
          ),
  en('l       ar        '):    :
    f.write(text)
