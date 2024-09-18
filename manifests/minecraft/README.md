# Minecraft Setup

## 1. Deploy once

Create minecraft files and DB files.

## 2. Proxy (Velocity) Server Configuration

Copy secret from Velocity server, then paste to `data/config/paper-global.yml`.

## 3. Confirm to connect server

## 4. Plugin Configuration

### 4.1 Paste copied config

- AxGraves
- DiscordIntegration
- LuckPerms
- LWC
- WorldGuard

### 4.2 DB config

Execute following SQL in Mariadb console.

```sql
CREATE TABLE IF NOT EXISTS `worldguard`.`blacklist_events` (
 `id` int(11) NOT NULL AUTO_INCREMENT,
 `world` varchar(10) NOT NULL,
 `event` varchar(25) NOT NULL,
 `player` varchar(16) NOT NULL,
 `x` int(11) NOT NULL,
 `y` int(11) NOT NULL,
 `z` int(11) NOT NULL,
 `item` int(11) NOT NULL,
 `time` int(11) NOT NULL,
 `comment` varchar(255) DEFAULT NULL,
 PRIMARY KEY (`id`)
);
```

## 5. LuckPerms configuration

### 5.1 Add LuckPerms permission to my own account

In server console, execute following command.

```shell
rcon-cli "lp user itk13201 permission set lickperms.* true"
```

### 5.2 Add groups

top level parent is "default"

- admin
- moderator

### 5.3 Admin permission config

Add `*` permission.

### 5.4 Default permission config

Add following permissions.

- `chestsort.use`
- `chestsort.use.inventory`
