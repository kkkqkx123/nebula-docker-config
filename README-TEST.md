# NebulaGraph 测试脚本使用说明

本目录包含用于测试NebulaGraph集群基本功能的PowerShell脚本。

## 测试脚本列表

### 1. `test-nebula.ps1` - 基础测试脚本
- **用途**: 快速验证nebula-console连接和基本功能
- **测试内容**:
  - 检查nebula-console是否存在
  - 测试连接到Graph服务(127.0.0.1:9669)
  - 验证存储和元数据服务状态
  - 创建测试空间和基本模式
- **执行时间**: 约10-20秒
- **使用方法**: `\.\test-nebula.ps1`

### 2. `test-nebula-complete.ps1` - 完整测试脚本
- **用途**: 全面测试NebulaGraph的各项功能
- **测试内容**:
  - 基础连接测试
  - 空间操作(创建、列出、使用)
  - 模式操作(标签和边类型创建)
  - 数据操作(插入和查询顶点)
  - 性能测试
  - 自动清理
- **执行时间**: 约30-60秒
- **使用方法**: `\.\test-nebula-complete.ps1`

## 先决条件

1. **nebula-console**: 确保nebula-console已安装并在PATH中，或放在当前目录下
2. **NebulaGraph服务**: 确保NebulaGraph集群正在运行
3. **连接参数**: 默认连接127.0.0.1:9669，用户root，密码nebula

## 使用步骤

1. **验证服务状态**:
   ```powershell
   # 检查Docker容器状态
   wsl -e bash -cl "cd /home/docker-compose/nebula && docker-compose ps"
   ```

2. **运行基础测试**:
   ```powershell
   .\test-nebula.ps1
   ```

3. **运行完整测试**:
   ```powershell
   .\test-nebula-complete.ps1
   ```

## 测试结果解读

### 基础测试输出
- **连接成功**: Graph服务正常运行，可以连接
- **存储服务检测到**: 存储节点正常运行
- **元数据服务检测到**: 元数据服务正常运行
- **空间创建成功**: 可以创建图空间

### 完整测试输出
- **所有测试通过**: NebulaGraph功能完全正常
- **性能评估**: 查询响应时间评估
- **服务状态**: 各组件运行状态

## 常见问题

### 1. nebula-console未找到
**错误**: `Error: nebula-console not found`
**解决**: 
- 确保nebula-console已安装
- 将nebula-console添加到PATH环境变量
- 或将nebula-console.exe放在脚本同目录下

### 2. 连接失败
**错误**: `Connection failed!`
**解决**:
- 检查NebulaGraph服务是否启动: `docker-compose ps`
- 检查端口9669是否开放
- 检查防火墙设置
- 验证用户名密码是否正确

### 3. 空间创建失败
**错误**: `Space creation failed!`
**解决**:
- 检查存储服务是否正常运行
- 检查空间配额限制
- 查看详细错误信息

### 4. 权限错误
**错误**: 权限相关的错误信息
**解决**:
- 确保使用root用户连接
- 检查用户权限配置
- 验证密码是否正确

## 故障排除

1. **检查服务日志**:
   ```powershell
   # 查看Graph服务日志
   wsl -e bash -cl "cd /home/docker-compose/nebula && tail -n 50 logs/graphd/graphd-stderr.log"
   
   # 查看存储服务日志
   wsl -e bash -cl "cd /home/docker-compose/nebula && tail -n 50 logs/storaged0/storaged-stderr.log"
   ```

2. **检查端口状态**:
   ```powershell
   # 测试端口连通性
   Test-NetConnection 127.0.0.1 -Port 9669
   Test-NetConnection 127.0.0.1 -Port 9779
   ```

3. **验证Docker容器**:
   ```powershell
   # 检查容器状态
   wsl -e bash -cl "docker ps | grep nebula"
   ```

## 高级用法

### 自定义连接参数
可以在脚本中修改以下参数：
- 地址: `127.0.0.1`
- 端口: `9669`
- 用户名: `root`
- 密码: `nebula`

### 扩展测试
可以基于现有脚本添加更多测试用例：
- 复杂查询测试
- 批量数据操作测试
- 并发连接测试
- 性能基准测试

## 注意事项

1. **测试环境**: 建议在测试环境中运行，避免影响生产数据
2. **清理**: 脚本会自动清理创建的测试空间
3. **性能**: 完整测试会创建临时数据，执行时间可能较长
4. **错误处理**: 脚本包含基本的错误处理和重试机制

## 支持

如遇到问题，请：
1. 检查NebulaGraph官方文档
2. 查看服务日志获取详细信息
3. 确保所有依赖服务正常运行
4. 验证网络连接和端口状态