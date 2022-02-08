# The official repository for the *Sonos Group Controller* Quick App for Fibaro Home Center 3

## Why I made this Quick App

There are some Sonos Quick Apps already available for the Home Center 3, but none of them can group and ungroup Sonos speakers. I wanted to create a Quick App that has little to no impact on my network. With the Home Center 3 it's not possible to subscribe to Sonos API events and you have to use polling. I don't like this to retrieve status updates so I used the minimal [Sonos Player](https://marketplace.fibaro.com/items/sonos-player-for-hc3) from [tinman](https://marketplace.fibaro.com/profiles/fibaro-user-unnamed-0d8b1f6e-6a22-4ed5-92be-7927e3617067)/[Intuitech](https://intuitech.de/) as a base to start.

## Possibilities

From a Lua scene (or Quick App) you can:

- Start a Sonos Favorite at a specified volume.
- Set the volume of a Sonos speaker.
- Save the player state (like `PLAY`/`STOP`) and automatically pause.
- Get the previous player state and resume this state.
- Create or add a Sonos speaker to a group.
- Remove a Sonos speaker from a group.

You can do more with the Quick App, like play an InTune / webradio station or play a local `.mp3` file from your NAS. Also you can send standard commands like `play`, `pause`, `stop`, `next` and `previous` but in this blog I focus on the above list.

## Documentation

You can read the full documentation of the Sonos Group Controller Quick App at:  
[https://docs.joepverhaeg.nl/sonos-group-controller/](https://docs.joepverhaeg.nl/sonos-group-controller/)