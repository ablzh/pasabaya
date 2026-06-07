# Pasabaya.app

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
