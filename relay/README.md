# Neural-Link: Teams Relay Server

This directory contains the lightweight Relay Server for the OpenClaw MS365 integration.

## Purpose

Microsoft Graph Webhooks (Change Notifications) require a public HTTPS endpoint that can:
1.  Respond to a validation handshake immediately (within 10s).
2.  Receive notification payloads.

Since local development machines (or firewalled servers) often cannot expose a public port easily, this Relay Server acts as the bridge. It sits on a public cloud VM (GCP), accepts the webhook, stores it (queue), and allows the internal MCP server to poll or fetch the data.

## Structure

- `src/server.ts`: Express server handling validation and queuing.
- `Dockerfile`: Container definition.
- `deploy-gcp.sh`: Automation to provision a GCP VM with a static IP.

## API Endpoints

### Public (Microsoft Graph)

- `POST /api/notification`
    - **Handshake:** Handles `?validationToken=...` by echoing the token.
    - **Notification:** Accepts JSON body and queues it.

### Internal (MCP Server)

- `GET /api/queue/pop`: Retrieve and remove the oldest notification.
- `GET /api/queue/peek`: Check queue status.
- `GET /health`: Health check.

## Deployment (Google Cloud)

**Prerequisites:**
- Google Cloud SDK (`gcloud`) installed and authenticated.
- A GCP Project selected.

**Steps:**

1.  **Run the provisioning script:**
    ```bash
    ./deploy-gcp.sh
    ```
    This reserves a static IP, opens port 8080, and starts an Ubuntu VM with Docker.

2.  **Deploy Code:**
    Follow the "Next Steps" printed by the script to `scp` the code and run the Docker container on the VM.

    Summary:
    ```bash
    # Pack
    tar -czf relay.tar.gz src package.json tsconfig.json Dockerfile

    # Upload
    gcloud compute scp relay.tar.gz ms365-teams-relay:~ --zone=us-central1-a

    # SSH & Run
    gcloud compute ssh ms365-teams-relay --zone=us-central1-a
    > tar -xzf relay.tar.gz
    > sudo docker build -t teams-relay .
    > sudo docker run -d -p 8080:8080 --restart always --name relay teams-relay
    ```

3.  **Configure MS365 Skill:**
    Use the printed Static IP as your `notificationUrl` base (e.g., `http://<STATIC_IP>:8080/api/notification`). 
    *Note: Production Graph Webhooks require HTTPS. You may need to add a domain and Let's Encrypt (Certbot) reverse proxy (Nginx) on the VM if using for real production.*

## Development

```bash
cd relay
npm install
npm run dev
```
