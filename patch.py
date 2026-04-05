import os

with open('lib/main.dart', 'r') as f:
    text = f.read()

old_str = '''                                       child: Material(                                          color: Colors.transparent,
                                          child: ListView(
                                            padding: const EdgeInsets.only(
                                              bottom: 24,
                                              top: 12,
                                            ),
                                            children: [
                                              _buildRouteOptionsSection(context),
                                            ],
                                          ),
                                        )),'''

new_str = '''                                       child: Material(
                                          color: Colors.transparent,
                                          child: hasRoutes 
                                              // support stop details wide layout
                                              ? ListView(
                                                  padding: const EdgeInsets.only(
                                                    bottom: 24,
                                                    top: 12,
                                                  ),
                                                  children: [
                                                    _buildRouteOptionsSection(context),
                                                  ],
                                                )
                                              : _buildStopDetailsContent(context, false),
                                        ),'''

if old_str in text:
    print('Found and replacing')
    text = text.replace(old_str, new_str)
    with open('lib/main.dart', 'w') as f:
        f.write(text)
else:
    print_str = 'Not found!'
    print(print_str)

