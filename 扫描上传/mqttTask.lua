--- 模块功能：MQTT客户端处理框架
module(..., package.seeall)

require "misc"
require "mqtt"
require "mqttOutMsg"
require "mqttInMsg"

local ready = false

--- MQTT连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage mqttTask.isReady()
function isReady()
    return ready
end

--启动MQTT客户端任务
sys.taskInit(
    function()
        local retryConnectCnt = 0
        while true do
            if not socket.isReady() then
                retryConnectCnt = 0
                --等待网络环境准备就绪，超时时间是5分钟
                sys.waitUntil("IP_READY_IND", 300000)
            end
            if socket.isReady() then
                local imei = misc.getImei()
                --创建一个MQTT客户端
                local mqttClient = mqtt.client(imei, 600, "", "")
                --阻塞执行MQTT CONNECT动作，直至成功
                if mqttClient:connect("39.108.117.70", 36003, "tcp") then
                    retryConnectCnt = 0
                    ready = true
                    --订阅主题
                    if mqttClient:subscribe({["/" .. imei] = 0}) then
                        mqttOutMsg.init()
                        --循环处理接收和发送的数据
                        while true do
                            if not mqttInMsg.proc(mqttClient) then
                                log.error("mqttTask.mqttInMsg.proc error")
                                break
                            end
                            if not mqttOutMsg.proc(mqttClient) then
                                log.error("mqttTask.mqttOutMsg proc error")
                                break
                            end
                        end
                        mqttOutMsg.unInit()
                    end
                    ready = false
                else
                    retryConnectCnt = retryConnectCnt + 1
                end
                --断开MQTT连接
                mqttClient:disconnect()
                if retryConnectCnt >= 5 then
                    link.shut()
                    retryConnectCnt = 0
                end
                sys.wait(5000)
            else
                --进入飞行模式，20秒之后，退出飞行模式
                net.switchFly(true)
                sys.wait(20000)
                net.switchFly(false)
            end
        end
    end
)
