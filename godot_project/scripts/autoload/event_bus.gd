## event_bus.gd
## 全局事件总线 (Autoload) — Phase 1 实现
##
## 用于解耦核心系统，取代 Autoload 之间的直接方法调用。
## 参考设计文档: EventBus_Architecture_Design.md (tsk-c61b04fa-930)
##
## 使用方法:
##   发布事件: EventBus.publish(Events.GAME_RESET)
##   订阅事件: EventBus.subscribe(Events.GAME_RESET, _on_game_reset)
##   取消订阅: EventBus.unsubscribe(Events.GAME_RESET, _on_game_reset)
extends Node

## 内部事件注册表：事件名称 -> Signal 对象
var _registry: Dictionary = {}

## 发布一个事件，通知所有订阅者
## @param event_name: 事件的唯一名称，建议使用 Events 常量
## @param payload: 伴随事件发出的数据 (通常是 Dictionary)
func publish(event_name: String, payload: Variant = null) -> void:
	if not _registry.has(event_name):
		# 事件从未被订阅，静默忽略（不报错，避免初始化顺序问题）
		return
	_registry[event_name].emit(payload)

## 订阅一个事件
## @param event_name: 要订阅的事件名称
## @param callback: 事件触发时调用的函数 (Callable)
## 注意：回调函数的签名应为 func(payload: Variant) -> void
func subscribe(event_name: String, callback: Callable) -> void:
	if not _registry.has(event_name):
		# 首次订阅时，动态创建信号
		add_user_signal(event_name, [{"name": "payload", "type": TYPE_NIL}])
		_registry[event_name] = Signal(self, event_name)
	
	if not _registry[event_name].is_connected(callback):
		_registry[event_name].connect(callback)

## 取消订阅一个事件
## @param event_name: 要取消订阅的事件名称
## @param callback: 之前用于订阅的回调函数
func unsubscribe(event_name: String, callback: Callable) -> void:
	if _registry.has(event_name) and _registry[event_name].is_connected(callback):
		_registry[event_name].disconnect(callback)

## 检查某个事件是否有订阅者
func has_subscribers(event_name: String) -> bool:
	return _registry.has(event_name) and _registry[event_name].get_connections().size() > 0

## 获取事件总线的调试信息
func get_debug_info() -> Dictionary:
	var info: Dictionary = {}
	for event_name in _registry:
		info[event_name] = _registry[event_name].get_connections().size()
	return info
