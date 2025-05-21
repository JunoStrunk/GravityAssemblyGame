# Design Brief - Space Delivery

## Concept

Space Delivery is a game where you take packages between different planets. You have to navigate around gas giants that threaten to pull you in with their gravity. Swing yourself around and make safe deliveries to increase your score!

Packages will appear at random planets and need to be delivered to random planets. When the player collides with a planet with a package, they will pick up the package. When the player collides with another planet while carrying a package they will deliver it to that planet. The player will earn score points when they correctly deliver packages.

Gas giants will have a gravitational pull that pulls the player towards them. The player can use these gas giants to sling themselves around.

See explanation image for what it looks like in my head!

## Implementation Plan

### Core

Total Hour Estimation - 27 hrs
Real Hour Cost - 

- Get player input and move primitive (3hrs) - Done (1:29:45)
- Player input moves bitmap (1hr) - Done (3:52:49)
- Draw bitmap background (1hr) - Done (1:10:35)
- Create "Object Module" (2 hrs)
- Collision detection between two entities (4hrs)
- Physics gravity effects player movememnt (5hrs)
- Figure out randomness (2hrs)
- Create "Planet Module" (3hrs)
    - Holds location
    - BMP name
    - Gas giant flag
    - Has delivery flag
    - Is destination flag
- Have package primitive be drawn at a random planet (3hrs)
- Switch out player sprite upon collision (1hr)
- Stop player movement upon collision (2hr)
- Draw bitmap upon collision (1hr)
- Score with 7 segment display (4hrs)
- Increase score when package delivered (3hrs)
- Redraw random planet to indicate delivery planet (1 hr)

### Stretch

Total Hour Estimation - 18 hrs
Real Hour Cost - 

- Packages spawn based on a random timer (4 hrs)
- Multiple packages spawn at the same time (4 hrs)
- Background music (5 hrs)
- Background sound effects (5 hrs)

## Risks and Mitigation
- Bitmap renderer is not efficient enough to draw player at a decent framerate
    - Switch player from bitmap to primitive
- Planet gravity does not allow player to sling and have fun or isn't properly      implemented
    - Switch design to have player avoid obstacles while falling downwards
    - Parachuter trying to hit a target while falling


