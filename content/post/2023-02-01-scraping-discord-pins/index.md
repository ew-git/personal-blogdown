---
title: Scraping Discord pins
author: Evan Wright
date: '2023-02-01'
slug: scraping-discord-pins
categories: []
tags:
  - discord
  - javascript
---

As more online communities move to Discord, it's becoming increasingly 
difficult to find coherent information within those communities. 
Often, important findings and frequently asked questions are scattered in
pinned messages throughout channels in the server. 
Discord search is not great, and navigating through pins is tiresome, so I
wrote a hacky script to scrape all pinned messages in a server to 
a single Markdown file. 

The script grabs the user's authentication token from the browser to
call Discord's API. A bot would be more convenient and maintainable,
but bots need approval by server admins, which is yet another step of friction. 
Instead, we may run this script directly in Chrome's JavaScript console, for example, which is 
good enough for my purposes. *If you don't know what it means to use the JS console,
you shouldn't be copying and pasting code you found on the internet. Please do some
searching to learn before coming back here; [this](https://developer.chrome.com/docs/devtools/console/) is
a good resource from the Chrome team.*

The only manual input for the script is the guild ID (guilds are also called servers). 
To get the ID, open Discord, go to Settings > Advanced and enable developer mode. Then, right-click on the server title and select "Copy ID" to get the guild ID.

The script grabs the user authentication token from the app's storage. 
The code here is copied from Stack Overflow; refer to the linked question if it stops working. 
Maybe someone has found a new method. 
Next, we use the API endpoint [`/guilds/{guild.id}/channels`](https://discord.com/developers/docs/resources/guild#get-guild-channels) to get a list of
channels in the server and sort by display position. 
Then, we loop through the channels to get pinned message content with 
[`/channels/{channel.id}/pins`](https://discord.com/developers/docs/resources/channel#get-pinned-messages). 
Images are attachments to messages, so they require some special handling. 
Instead of downloading the images, we create hotlinks to the Discord CDN---which, by the way, requires no authentication. 
This may or may not work for your use case; one could manually download the images instead. 

Finally, we stuff the channel content and image links into a single `<pre>` tag, which we
then display in a new window. 
The Markdown structure is an H1 header of the channel name followed by all pinned message contents.
The content of the pop-up should be copiable as Markdown. 
Formatting errors aside, one may render the Markdown however one chooses for a single easily searchable and browseable help file. 

```javascript
// To get the server ID, open Discord, go to Settings > Advanced and enable developer mode. Then, right-click on the server title and select "Copy ID" to get the guild ID.
let GUILDID = "1111"; // CHANGE ME

// See https://stackoverflow.com/a/69868564
let TOKEN = (webpackChunkdiscord_app.push([[''],{},e=>{m=[];for(let c in e.c)m.push(e.c[c])}]),m).find(m=>m?.exports?.default?.getToken!==void 0).exports.default.getToken();

let textchannels = await fetch("https://discord.com/api/v9/guilds/" + GUILDID + "/channels", {
  "headers": {
    "accept": "*/*",
    "authorization": TOKEN,
 },
  "body": null,
  "method": "GET",
  "mode": "cors",
  "credentials": "include"
})
  .then(response => response.json())
  .then(channels => {
        let result = [];
        for (let i = 0; i < channels.length; i++) {
            if (channels[i].type === 0){
            result.push(channels[i]);
            }
        }
        return result;
    }
);

// https://stackoverflow.com/a/69026789
textchannels.sort((a, b) => {
    var ret;
    if (a.position < b.position) {
        ret = -1;
    } else if (a.position > b.position) {
        ret = 1;
    } else {
        ret = 0;
    }
    return ret
});

let pincontents = ['<pre>'];

for (let i = 0; i < textchannels.length; i++){
    console.log("Getting pins for channel = " + JSON.stringify(textchannels[i]));
    pincontents.push("[//]: # (COMMENT: channel = " + JSON.stringify(textchannels[i]) + ')');
    pincontents.push("# " + textchannels[i]['name']);
    // https://stackoverflow.com/a/51939030
    // Need to avoid 429
    await new Promise(resolve => setTimeout(resolve, 2000));
    await fetch("https://discord.com/api/v9/channels/" + textchannels[i]['id'] + "/pins", {
        "headers": {
            "accept": "*/*",
            "authorization": TOKEN,
        },
        "body": null,
        "method": "GET",
        "mode": "cors",
        "credentials": "include"
        })
        .then(response => response.json())
        .then(pins => {
                for (let i = 0; i < pins.length; i++) {
                    pincontents.push(pins[i]['content']);
                    for (let j = 0; j < pins[i]['attachments'].length; j++) {
                        pincontents.push('\n![Image](' + pins[i]['attachments'][j]['url'] + ')\n');
                    }
                    
                }
            }
        );
}
pincontents.push('</pre>');

console.log(pincontents.join("\n\n"));

// May need to allow pop-ups. If it fails, just run these lines again.
var win = window.open("", "Pins", "toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=yes,resizable=yes,width=780,height=200,top="+(screen.height-400)+",left="+(screen.width-840));
win.document.body.innerHTML = pincontents.join("\n\n");
```

Sample output (redacted):
```md

[//]: # (COMMENT: channel = {..."name":"displayedfirst","position":0,...})

# displayedfirst

asdf

[//]: # (COMMENT: channel = {..."name":"general","position":1...})

# general

longer message 
😀 
maybe


![Image](https://cdn.discordapp.com/attachments/....png)


![Image](https://cdn.discordapp.com/attachments/....png)


Another pin with bold *asdf* _bold_
1. 3
2. 6

test pinned

[//]: # (COMMENT: channel = {..."name":"otherchannel","position":2,...)

# otherchannel

other chan pin
```

One nagging issue is 429 (Too Many Requests) 
responses when querying each channel. The script simply waits 2 seconds between 
requests to avoid them. For large servers, this may be annoyingly long, but
retry logic just complicates the script. 
