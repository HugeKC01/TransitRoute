with open("lib/main.dart", "r") as f:
    code = f.read()

count1 = code.count("allRoutes.where")
count2 = code.count("allRoutes.firstWhere")

print(f"where: {count1}, firstWhere: {count2}")
