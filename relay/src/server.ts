import express, { Request, Response } from 'express';
import bodyParser from 'body-parser';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(bodyParser.json());

// In-memory queue for notifications (POC/Simple)
// In production, use Redis or SQLite
const notificationQueue: any[] = [];

// Logger
const log = (msg: string) => console.log(`[${new Date().toISOString()}] ${msg}`);

/**
 * Health Check
 */
app.get('/health', (req: Request, res: Response) => {
  res.status(200).send('OK');
});

/**
 * Microsoft Graph Notification Endpoint
 * Handles both validation handshake and actual notifications
 */
app.post('/api/notification', (req: Request, res: Response) => {
  // 1. Validation Handshake
  // Microsoft sends a validationToken query parameter.
  // We must return it within 10 seconds in plain text with a 200 OK.
  const validationToken = req.query.validationToken as string;
  if (validationToken) {
    log(`Received validation request. Token: ${validationToken}`);
    res.status(200).send(validationToken); // Must be text/plain by default for express send(string)
    return;
  }

  // 2. Process Notification
  try {
    const body = req.body;
    
    // Microsoft Graph sends a 'value' array containing change notifications
    if (body.value && Array.isArray(body.value)) {
      body.value.forEach((notification: any) => {
        log(`Queuing notification: ${notification.resource}`);
        notificationQueue.push({
          receivedAt: new Date(),
          data: notification
        });
      });
    } else {
      log('Received payload without value array');
    }

    // Always return 202 Accepted to Microsoft immediately
    res.status(202).send();
  } catch (error) {
    console.error('Error processing notification:', error);
    // Still return 202 to prevent Graph from retrying endlessly if it's a format issue
    res.status(202).send(); 
  }
});

/**
 * DEBUG/INTERNAL: Poll Queue
 * Retreive and clear notifications (FIFO)
 */
app.get('/api/queue/pop', (req: Request, res: Response) => {
  if (notificationQueue.length === 0) {
    res.status(204).send(); // No Content
    return;
  }
  
  const item = notificationQueue.shift();
  res.json(item);
});

app.get('/api/queue/peek', (req: Request, res: Response) => {
  res.json({ count: notificationQueue.length, latest: notificationQueue[0] || null });
});

// Start Server
app.listen(PORT, () => {
  log(`Relay server running on port ${PORT}`);
});
