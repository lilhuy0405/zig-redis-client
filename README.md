# A sime redis client implement with zig
- Zig is a high performance language but not for noob
- I tried to implement a simple redis which send tcp bufffer to redis server read the respone but this simple approuch is super low about 400 tps ?
- After researching i know that to increase tps we need to implement command queued and connection pool and this simple redis client can reack 16k tps
# How to run
- Prepare your redis here im using dragonflydb for redis you can use orignal redis as you wish
```bash
docker run --network=host --ulimit memlock=-1 docker.dragonflydb.io/dragonflydb/dragonfly
```
# Run the benchmark in main.zig
```bash
zig run src/main.zig
```
![image](https://github.com/user-attachments/assets/877872b0-c2ca-4a2a-806b-7fd04dbb9691)

