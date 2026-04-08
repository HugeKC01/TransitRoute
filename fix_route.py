with open("lib/main.dart", "r") as f:
    code = f.read()

code = code.replace("___routeStopIds.contains", "_routeStopIds.contains")
code = code.replace("__routeStopIds.contains", "_routeStopIds.contains")
with open("lib/main.dart", "w") as f:
    f.write(code)
