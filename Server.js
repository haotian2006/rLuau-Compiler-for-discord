//Taken and modified from https://github.com/RoSocket

const express = require('express');
const WebSocket = require('ws');
const axios = require('axios');
const tunnelmole = require('tunnelmole/cjs');
const https = require('https');

const universeId = 0
const msgUrl = `https://apis.roblox.com/messaging-service/v1/universes/${universeId}/topics/UpdateURL`;

//This is optional if you are just running in studio, 
//Give access to messeging service for your place 
const ROBLOX_API_KEY = ''; 

const DISCORD_BOT_TOKEN = ""
const DISCORD_Application_ID = ""
const app = express();
app.use(express.json());
const port = 6214;

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function getUrl()
{ 
    const url = await tunnelmole({
        port: port
    });
    return url;
}


const checkUrl = async (url) => {
    try {
      const response = await axios.get(url);
      if (response.status === 200) {
        return true
      } else {
        return false;
      }
    } catch (error) {
        return false;
    }
  };

  
async function fetchFileContent(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (response) => {
            let data = '';

            if (response.statusCode !== 200) {
                reject(new Error(`Failed to get data. Status Code: ${response.statusCode}`));
                return;
            }

            response.on('data', (chunk) => {
                data += chunk;
            });

            response.on('end', () => {
                resolve(data);
            });

        }).on('error', (err) => {
            reject(err);
        });
    });
}


 
const connections = {}; 

async function sendMsgToServer(msg){
    if (ROBLOX_API_KEY === '') {
        return;
      }
    const data = {
        message: JSON.stringify({url: msg}),
      };
      
      axios.post(msgUrl, data, {
        headers: {
          'x-api-key': ROBLOX_API_KEY,
          'Content-Type': 'application/json',
        }
      })
      .catch(error => {
        console.warn('Error:', "Failed to send message to Roblox server");
      });

}

function isValidWebSocketURL(url) {
    return url.startsWith("wss://");
}

function generateUUID() {
    return Math.random().toString(36).substring(2, 10);
} 


function handleWebSocketConnection(UUID, socket) {
    socket.on('message', (message) => {
        if (connections[UUID]) {
            const messageString = message.toString();
            const data = JSON.parse(messageString);
            if (data.t === 'INTERACTION_CREATE') {
                //method removed
            }
            connections[UUID].messages.push({
                id: generateUUID(),
                message: messageString,
                step: connections[UUID].messages.length + 1
            });
        }
    });
   socket.on('error', (error) => {
        console.warn(`WebSocket error for UUID: ${UUID}`, error);
        if (connections[UUID]) {
            connections[UUID].errors.push({
                id: generateUUID(),
                message: error,
                step: connections[UUID].errors.length + 1
            });
        }
    });
    socket.on('close', (msg) => {
        //delete connections[UUID];
    });
}


app.post('/callback', async (req, res) => {
    const interactionId = req.body.interactionId;
    const interactionToken = req.body.interactionToken;
    const url = `https://discord.com/api/v10/interactions/${interactionId}/${interactionToken}/callback`;
    
    const responseContent = req.body.data; 
let response;
   try {
      response = await axios.post(
        url,
        responseContent,
        {
            headers: {
                'Authorization': `Bot ${DISCORD_BOT_TOKEN}`,
                'Content-Type': 'application/json'
            }
        }
    );
    } catch (error) {
        console.log("Failed To Send",error.response.data);
        res.status(500).json({
            message: 'Failed to send response to Discord',
            error: error.response ? error.response.data : error.message
        });
        return;
        
    }
    res.json({
        message: 'Successfully sent response to Discord',
        data: response.data
    });
});

app.patch('/readfile', async (req, res) => {
    const url = req.body.url;
    try {
        const fileContent = await fetchFileContent(url);
        res.send(fileContent);
    } catch (error) {
        res.status(500).send(`Error reading file: ${error.message}`);
    }
});


app.patch('/respond', async (req, res) => {
    try {
        const token = req.body.token;
        const responseContent = req.body.data; 
      
        const url = `https://discord.com/api/v10/webhooks/${DISCORD_Application_ID}/${token}/messages/@original`;

        const response = await axios.patch(
            url,
            responseContent,
            {
                headers: {
                    'Authorization': `Bot ${DISCORD_BOT_TOKEN}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        res.json({ 
            message: 'Successfully sent response to Discord',
            data: response.data
        });
    } catch (error) {
      
        res.status(500).json({
            message: 'Failed to send response to Discord',
            error: error.response ? error.response.data : error.message
        });
    }

});

app.post('/connect', async (req, res) => {
    const { Socket } = req.body;
    if (!Socket) {
        return res.status(400).json({ success: false, error: "No WebSocket URL provided!" });
    }
    if (!isValidWebSocketURL(Socket)) {
        return res.status(400).json({ success: false, error: "Invalid WebSocket URL" });
    }

    const UUID = generateUUID();
    const socket = new WebSocket(Socket);

    try {
        await new Promise((resolve, reject) => {
            socket.on('error', (error) => {
                console.error(`WebSocket error for UUID: ${UUID}`, error);
                reject(error);
            });
            socket.on('open', () => {
                resolve();
            });
        });
    } catch (error) {
        return res.status(500).json({ success: false, error: "WebSocket connection error" });
    }

    connections[UUID] = { socket: socket, messages: [] };
    handleWebSocketConnection(UUID, socket);

    res.json({ UUID, Socket, success: true });
});


app.post('/disconnect', (req, res) => {
    const { UUID } = req.body;
    if (!UUID) {
        return res.status(400).json({ success: false, error: "No UUID provided!" });
    }
    if (!connections[UUID]) {
        return res.status(404).json({ success: false, error: "UUID not found" });
    }

    connections[UUID].socket.close();
    delete connections[UUID];

    res.json({ UUID, success: true });
});

app.post('/send', (req, res) => {
    const { UUID, Message } = req.body;
    if (!UUID || !Message) {
        return res.status(400).json({ success: false, error: "UUID or Message not provided!" });
    }
    if (!connections[UUID] || connections[UUID].socket.readyState !== WebSocket.OPEN) {
        return res.status(404).json({ success: false, error: "Invalid UUID or WebSocket connection closed" });
    }

    connections[UUID].socket.send(Message);
    res.json(true);
});

app.post('/get', (req, res) => {
    const { UUID } = req.body;
    if (!UUID) {
        return res.status(400).json({ success: false, error: "No UUID provided!" });
    }
    if (!connections[UUID]) {
        return res.status(404).json({ success: false, error: "Invalid UUID" });
    }

    res.json(connections[UUID].messages);
}); 
app.post('/errors', (req, res) => {
    const { UUID } = req.body;
    if (!UUID) {
        return res.status(400).json({ success: false, error: "No UUID provided!" });
    }
    if (!connections[UUID]) {
        return res.status(404).json({ success: false, error: "Invalid UUID" });
    }

    res.json(connections[UUID].errors);
});
app.get('/' , (req, res) => {
    res.send('Hello World!');
});


app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});


//This part is for tunneling 
(async () => {
    //Creates a new url 
    let url = await getUrl();
    console.log("New URL: ", url);
    while (true) {
        const isUrlWorking = await checkUrl(url);
        if (isUrlWorking) { 
            sendMsgToServer(url); //Updates the roblox server with the new url
        } else {
            //If the old url is not working, then get a new one
            url = await getUrl();
            console.log("New URL: ", url);
        }
        await delay(10000);
    }
})();

