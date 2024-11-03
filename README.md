# A sime redis client implement with zig
- Zig is a high performance language but not for noob
- I tried to implement a simple redis which send tcp bufffer to redis server read the response (send command -> wait for response -> send command -> wait for response) but this simple approach is super low about 30 tps ?
- After researching I know that to increase tps we need to implement command queued and connection pool and this simple redis client can reach 16k tps
- 16k maybe not the best but it's good enough for me althouth when run redis-benchmark can reach 100k tps
# How to run
- Prepare your redis here I'm using dragonflydb for redis you can use orignal redis as you wish
```bash
docker run --network=host --ulimit memlock=-1 docker.dragonflydb.io/dragonflydb/dragonfly
```
# Run the benchmark in main.zig
```bash
zig run src/main.zig
```
![image](https://github.com/user-attachments/assets/877872b0-c2ca-4a2a-806b-7fd04dbb9691)


Code in main is also the demonstration of how to use the redis client

# Current status
- Only support GET SET INCR commands (my zig project at current point just need to support these commands)
- Callback implementation: Personally I don't like callback but I have to use it in this case which can lead to call back hell (I'm a Javascript developer)
# Future plan
- Support more commands
- Try to create something like getAsync setAsync


