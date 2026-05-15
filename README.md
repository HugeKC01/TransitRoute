# 🚌 TransitRoute

**TransitRoute** is a cross-platform public transit app for the **Bangkok metropolitan area**, built with Flutter. It helps commuters plan multi-modal journeys across buses, metro lines, BRT, and ferries — all in one place.

> 🌐 **Live Web App:** [https://hugekc01.github.io/TransitRoute](https://hugekc01.github.io/TransitRoute)
>
> 📦 **Repository:** [https://github.com/HugeKC01/TransitRoute](https://github.com/HugeKC01/TransitRoute)
>
> 📱 **Google Play (Closed Testing):** [Join on Google Play](https://play.google.com/store/apps/details?id=com.hugekc.transitroute)
>
> 👥 **Google Group (Required to access):** [transitroute-bkk](https://groups.google.com/g/transitroute-bkk)

This app was developed as a senior project by students at **King Mongkut's University of Technology Thonburi (KMUTT)**.

---

## 📲 Download & Testing

TransitRoute is currently in **Closed Testing** on Google Play. To install it on Android:

1. **Join the Google Group** to get access:
   👉 [https://groups.google.com/g/transitroute-bkk](https://groups.google.com/g/transitroute-bkk)

2. **Opt in to the test** on Google Play:
   👉 [https://play.google.com/store/apps/details?id=com.hugekc.transitroute](https://play.google.com/store/apps/details?id=com.hugekc.transitroute)

3. Download and install the app from the Play Store.

> ⚠️ You must join the Google Group first — otherwise the Play Store link will show the app as unavailable.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🗺️ **Interactive Map** | Explore stops and routes on a live map with pinpoint accuracy |
| 🔍 **Route Search** | Plan multi-modal journeys across buses, metro, BRT, and ferries |
| 🕐 **Timetables** | View departure schedules for all supported transit lines |
| 💰 **Fare Calculator** | Estimate travel costs including zone-based and flat fares |
| 📡 **Transit Updates** | Browse the latest service alerts and disruptions |
| 📋 **Line Details** | Explore all stops and shapes for any transit route |
| 📍 **Station Info** | See connecting lines, fares, and timetables for any stop |
| 🗾 **Graphic Map** | Visual schematic map of the Bangkok transit network |
| 🃏 **Transit Cards** | Information on payment cards accepted across transit modes |
| 📡 **GTFS Sync** | Automatically syncs fresh GTFS data from Firebase Storage |

---

## 🛠️ Tech Stack

- **Framework:** Flutter (Dart) — targeting Android, iOS & Web
- **Maps:** [`flutter_map`](https://pub.dev/packages/flutter_map) with OpenStreetMap tiles
- **Database:** SQLite via [`sqflite`](https://pub.dev/packages/sqflite) for offline GTFS data
- **Backend:** Firebase (Cloud Firestore + Firebase Storage) for transit updates & GTFS sync
- **Routing Engine:** Custom multi-modal direction service (`direction_service.dart`)
- **Data Format:** GTFS (General Transit Feed Specification)
- **Fonts:** Google Fonts via [`google_fonts`](https://pub.dev/packages/google_fonts)

---

## 📁 Project Structure

```
lib/
├── main.dart                  # App entry point & navigation shell
├── pages/
│   ├── navigation_page.dart   # Journey planner & route search
│   ├── transport_lines_page.dart     # All transit lines browser
│   ├── transport_lines_details_page.dart  # Line stop map & details
│   ├── station_details_page.dart    # Individual station info
│   ├── transit_updates_list_page.dart  # Service alerts
│   ├── graphic_map_page.dart  # Schematic network map
│   ├── cards_page.dart        # Transit card guide
│   ├── more_page.dart         # Settings & extra info
│   └── about_page.dart        # About & credits
├── services/
│   ├── direction_service.dart # Multi-modal routing engine
│   ├── fare_calculator.dart   # Fare estimation logic
│   ├── timetable_service.dart # Schedule lookup
│   ├── route_asset_loader.dart# GTFS asset parser
│   ├── gtfs_sync_service.dart # Firebase GTFS sync
│   ├── gtfs_shapes.dart       # Route polyline builder
│   ├── gtfs_models.dart       # GTFS data models
│   └── transit_update_service.dart # Firestore alerts
└── widgets/
    ├── station_details_content.dart
    └── station_timetable.dart
```

---

## 🗃️ Data Sources

| Source | Type | Link |
|---|---|---|
| Mobility Database | GTFS (Metro/Rail) | [mdb-1831](https://mobilitydatabase.org/feeds/gtfs/mdb-1831) |
| Chao Phraya Express Boat | Ferry timetables & fares | [chaophrayaexpressboat.com](https://www.chaophrayaexpressboat.com/chaophrayaexpressboat) |
| BMTA | Bus routes & stops | [bmta.co.th](https://www.bmta.co.th/bus-lines) |
| BEM Metro | MRT Blue & Purple lines | [metro.bemplc.co.th](https://metro.bemplc.co.th/?lang=th) |
| BTS SkyTrain | BTS Sukhumvit & Silom | [bts.co.th](https://www.bts.co.th/) |

---

## ⚠️ Disclaimer

TransitRoute is a **prototype** built for academic purposes. Transit data may be **incomplete or outdated**. Always verify departure times, fares, and service availability with official transit operators before travelling.

---

## 📦 Open Source Packages

This app is built on the following open-source Flutter packages:

`archive` · `cloud_firestore` · `collection` · `cupertino_icons` · `firebase_core` · `firebase_storage` · `flutter_map` · `flutter_svg` · `google_fonts` · `http` · `latlong2` · `location` · `path_provider` · `shared_preferences` · `sqflite` · `url_launcher`

---

## 📄 License

| Component | License |
|---|---|
| App source code | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
| Transit data | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

---

<p align="center">
  Made with ❤️ at KMUTT · Bangkok, Thailand
</p>
