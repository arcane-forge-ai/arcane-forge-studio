# Feedback Integration

## Summary

- A set of pages to:
  - browse all feedbacks
  - analyze feedbacks
- User flow
  1. click on side menu item `Feedbacks`
  2. a screen that contains:
    - a table or any other viewer friendly UI to display all the feedbacks
    - a button to start an analyze session
    - a place to show all past analyze sessions
  3. For Analyze, we will have two types of analyzation:
    1. Free discuss (basically a chat window), just like what we have for game design assistant
    2. Analyze feedbacks and generate an improvement doc for next iteration
      - difference between this and free discuss is that we will have a preset prompt to send as first message of the conversation (hidden to user). And user will look at the result and then start ask questions
- To get feedbacks, make a GET call to `https://games.arcaneforge.ai/api/games/{game_slug}/feedback`, where we could just do `https://games.arcaneforge.ai/api/games/shape-rogue-v2/feedback` always for now (and we will replace this url after we implement other logics)
- You can find a sample feedback response under [sample-feedback.json](./design_docs/sample-feedback.json)