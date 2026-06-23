# [Pasabaya.app](https://pasabaya.app/)

```text
  ____                                  _                           _                      
 |  _ \  __ _  ___   __ _  |__ \  __ _  _   _   __ _        __ _  _ __  _ __  
 | |_) |/ _` |/ __| / _` | |  _ \/ _` || | | | / _` |      / _` || '_ \| '_ \ 
 |  __/| (_| |\__ \| (_| | | |_) | (_| || |_| || (_| |  _ | (_| || |_) || |_) |
 |_|    \__,_||___/ \__,_| |____/ \__,_| \__, | \__,_| (_) \__,_|| .__/ | .__/ 
                                         |___/                   |_|    |_|    
```

---
## The Philosophy

As the industry moves toward microservices and division of responsibility, Rails proves that a single developer, with the right monolith at their disposal, can compete on their own with entire product teams.

This project demonstrates that a single developer can build a fully functional SaaS product—from frontend and backend to deployment on a production server and ongoing maintenance—while balancing it with a full-time job and university studies.

In creating Pasabaya.app, I was inspired by **The One Person Framework** philosophy. The source code is open, and the codebase is designed to be as simple as possible, making it easy for others to understand, contribute, and suggest improvements.

## Technical Stack

The project leverages **Rails 8.1** capabilities to their fullest, adhering to the principle of minimizing external dependencies.

| Task | Industry Stack | Ruby on Rails Stack (Default) |
| :--- | :--- | :--- |
| **Database** | PostgreSQL / MySQL | SQLite (Production-ready configuration) |
| **Interactive UI** | React + Next.js + Redux | Hotwire (Turbo + Stimulus) |
| **Job Queues** | Redis + Sidekiq / Celery | Solid Queue (SQLite-backed) |
| **Caching** | Redis / Memcached | Solid Cache (SQLite-backed) |
| **Frontend Build** | Node.js + Webpack / Vite | Import Maps (Native JS in the browser) |
| **Deployment** | Kubernetes / AWS ECS | Kamal (Simple SSH + Docker) |

---

## 🚀 How to run locally

**First time contributing?** Welcome! This guide will help you get the website running locally in just a few steps. 

Thanks to the **Solid Trifecta** (Solid Queue, Solid Cache, and Solid Cable) running on SQLite, there is no need for Redis, Memcached, or any other external services. The project runs fully on SQLite and Import Maps, meaning you don't need to install PostgreSQL, Redis, or Node.js to get started.

### Prerequisites

- **macOS / Linux / Windows with WSL2 (Ubuntu)** — If you are on Windows, I assume you are using WSL2 to run the commands.
- **Ruby 4.0.1** (I recommend installing it via [mise](https://mise.jdx.dev/))
- **Git**

### Get It Running

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ablzh/pasabaya.git
   cd pasabaya
   ```

2. **Run the setup script**:
   ```bash
   bin/setup
   ```
   *This command will install all gems, prepare your SQLite database, and boot the development server.*

3. **Access the app**: Open your browser and navigate to `http://localhost:3000` to see the app in action!

4. To log in, use the test user data: 
_email:_ admin@example.com 
e_password:_ password

## Monitoring
The public-facing performance dashboard for this application is available at [Skylight OSS](https://oss.skylight.io/app/applications/6Ku64X6eveQt/recent/6h/endpoints)
