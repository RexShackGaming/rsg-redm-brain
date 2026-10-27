# **VORP Police Script**

This is a comprehensive police system for RedM using the VORP framework. It integrates various police-related functionalities, such as an on-duty system, shared/private storages, job management, and more. The script is designed for small to large servers and offers customization options to suit different server needs.

---

## **Installation**

1. Download or clone the repository to your server's resources folder.
2. Add `ensure vorp_police` to your `server.cfg` file to ensure the script is loaded when the server starts.
3. Make sure the required dependencies are installed and properly configured.
4. This script registers automatically jobs to vorp core.

## **Features**

### **Storage System**
- Supports **shared** and **private** storages for police officers.
- Configurable item limits, allowing for a flexible inventory management system within the police force.

### **On-Duty System**
- Utilize **statebags** to track whether players are on or off duty for light checks.

### **Teleport System**
- Set up teleport points for **fast travel** between different police stations or key locations.
- Useful for both small and large servers, allowing for quick responses and movement across the map.

### **Boss Menu**
- **Hire and fire players** via the boss menu, offering easy job management for police chiefs or higher-ranking officers.
- Simple and intuitive menu with all the necessary functionalities for managing the police force.

### **Drag Players**
- Drag nearby players using a **drag player** feature, adding realism and functionality during arrests or detainment scenarios.

### **Cuff System**
- **Cuffs as items:** Police officers can use cuffs to detain suspects, and keys to release them.
- Realistic mechanics for handcuffing and uncuffing, with item-based restrictions.

### **Jail System**
- **Persistent jail time:** Jail time lasts even after server relogs.
- **Teleportation to Sisika:** Players are automatically teleported to Sisika when jailed.
- **Jail commands:** With the correct permissions can jail, unjail, and adjust jail time.
- **Jail time checks:** Players can check how much jail time is left via command.
- **Respawn/Dead/Escape Protection:** Players cannot respawn when inside Sisika through respawn prompt. They will automatically respawn when they die.

---

## **Dependencies**

This script requires the following VORP resources to function properly:

- **[VORP Core](https://github.com/VORPCORE/vorp_core-lua)**: Provides essential functions and event handlers used throughout the script.
- **[VORP Inventory](https://github.com/VORPCORE/vorp_inventory-lua)**: Manages the item-based inventory system, including cuffs and keys.
- **[VORP Menu](https://github.com/VORPCore/vorp_menu)**: Powers the interactive menu system, used for the boss menu, hire/fire system, and teleportation points.
- **[VORP Lib](https://github.com/VORPCORE/vorp_lib)**: Supplies shared utilities, including the PolyZones module now used for jail boundaries.

Ensure you have these resources installed and correctly set up for the `vorp_police` script to work seamlessly.

---

## **Usage**

1. **Storage**: Officers can access shared or private storage depending on configuration.
2. **On-Duty**: Use commands or menu options to go on or off duty.
3. **Teleport**: Teleports can be configured for quick travel between key locations.
4. **Boss Menu**: Manage the police force by hiring and firing players directly through the boss menu.
5. **Drag Players**: When in close proximity, drag players as part of arrest procedures.
6. **Cuffs**: Officers can use cuffs and keys, which must be present in their inventory to handcuff or uncuff players.

---

## **Commands**

1. **/drag**: Drag/escort a nearby player.
2. **/policeMenu**: Open the police menu to go on duty or access other functionalities.
3. **/callpolice**: Call for police assistance.
4. **/cancelPoliceAlert**: Cancel a police alert.
5. **/finishPoliceAlert**: Finish a police alert.
6. **/jail**: Jail a player. Usage: `/jail <player id> <time in minutes>`.
7. **/unjail**: Unjail a player. Usage: `/unjail <player id>`.
8. **/changejailtime**: Change jail time. Usage: `/changejailtime <player id> <time in minutes>`. To reduce time, use negative numbers (e.g., `-10` will reduce 10 minutes).
9. **/checkjailtime**: Check jail time for jailed players to see how long they have left.

---

## **Configuration**

You can configure the script to suit your server's needs. The following settings can be adjusted in the configuration file:

- **Storage Settings**: Define limits for shared or private storage, and enable/disable features like weapon storage.
- **Duty Settings**: Customize the duty system, including state management.
- **Job Labels**: Add or modify police job labels for hire/fire functionality.
- **Teleport Locations**: Set up teleport points for police stations or other important areas on the map.

---

## **Support and Updates**

For support or further information, please ask in the [Vorp Core Discord](https://discord.gg/JjNYMnDKMf). Updates will be released periodically to improve functionality or compatibility with the latest VORP framework versions.


## **Exports**

```lua
local isOnDuty = exports.vorp_police:isOnDuty(source)
local policeId = exports.vorp_police:getPoliceFromCall(source) -- returns id source if on call or 0
```
