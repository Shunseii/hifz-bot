Check if data/hifz.json exists in the hifz skill directory.

If it does not exist, message the user and ask them to start
onboarding by saying "I want to set up my hifz tracking".

If it exists and the user has not yet received a schedule today
(lastUpdated in hifz.json does not match today's date), read
prompts/heartbeat.md from the hifz skill and generate today's
review schedule. Send it to the user via Discord.

If the user has already received a schedule today, reply
HEARTBEAT_OK.
