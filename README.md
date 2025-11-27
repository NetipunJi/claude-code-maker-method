# Claude Code setup with MAKER methods

Solving a Million-Step LLM Task with Zero Errors
[Reseach Paper](https://arxiv.org/abs/2511.09030)

## Don't forget to make script executable

```bash
chmod +x .claude/hooks/maker-post-task.sh
chmod +x .claude/hooks/check_winner.py
```

Change step-executor agent model to "haiku" if you hit rate-limit too fast