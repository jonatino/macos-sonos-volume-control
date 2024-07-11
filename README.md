I use a Sonos Arc as my speaker. When connected to my dock, my Macbook is unable to control the volume of HDMI/Display Port devices. This is INCREDIBLY frustrating and primitive. 

The goals for this app are simple. Adjust the volume of an external sonos device using the minimal amount of code. I don't want to manage creating virutal devices or creating audio loopback drivers etc. I've tried all of the apps that used those solutions, and they for whatever reason break or have fatal flaws (breaking between macOS updates, just general driver crashing etc). I wanted something simple that "just works".

This app does and will only ever do 3 things:
- Hooks the volume up, volume down, and mute keys (to control the volume. This is why "Accessibility" permission is needed)
- When any of those buttons are pressed, a command is sent to your Sonos device telling it to change the volume. It then reports back its current volume level.
- To show the user the volume is changing, we use some of Apple's private API's to fake the on-screen volume display (shout out to https://github.com/MonitorControl/MonitorControl). This allows us to emulate native volume changing behavior perfectly.

Future goals (I'm open to contributions, but any additional complexity will be rejected):
- Change to .app format instead of command line app
- Tray icon with Quit/Settings option
- Very basic ui with single input for Sonos device name

Credits:

https://github.com/MonitorControl/MonitorControl - For the volume OSD stuff

https://github.com/denisblondeau/SonosAPIDemo - For the sonos api
