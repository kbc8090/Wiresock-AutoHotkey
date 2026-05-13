Minimal setup to control various VPN profiles via Wiresock.  This is the most minimal setup I could conjure up to do such a thing.  I'll list the steps of kind of how I got here

- I have various VPN configs, Mullvad/Proton/Cloudlare WARP.  I only really care about tunneling browser traffic so I use wiresock to do so which does it at the application level.  I also like that wiresock can do transparent mode wireguard without creating a new virtual adapter.
- Running the app in total is about 110megs of ram, which is fine,but seems unecessary.
- I found that Wiresock offers a SDK, so you can just run the wiresock config from the command line, so thats cool.
- I asked AI about the lightest weight solution to control this and found Autohotkey V2.  This worked very well
- I created a system tray app with a red/green icon.  It can connect/disconnect, auto-connect/reconnect, you can select which profile you want and it kills/reloads the wiresock-client.exe process.  Monitors connectivity.  When the process is disconnected or killed it sends a toast notification.  Takes up 2mb of ram.

Overall pretty satisfied, 12mb of ram usage and I'm only split tunneling msedge.exe, chrome.exe, firefox.exe, qbitorrent.exe.  Everything else I don't really care about.
