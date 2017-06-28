# kubeadm-highavailiability - 基于kubeadmin的kubernetes高可用集群部署

![CookIM logo](images/Kubernetes.png)

- [中文文档](README-ZH.md)
- [English document](README.md)

---

- [GitHub项目地址](https://github.com/cookeem/kubeadm-ha/)
- [OSChina项目地址](https://git.oschina.net/cookeem/kubeadm-ha/)

---

### 目录

1. [部署架构](#部署架构)
    1. [概要部署架构](#概要部署架构)
    1. [详细部署架构](#详细部署架构)
    1. [主机节点清单](#主机节点清单)
1. [安装前准备](#安装前准备)
    1. [版本信息](#版本信息)
    1. [所需docker镜像](#所需docker镜像)
    1. [系统设置](#系统设置)
1. [kubernetes安装](#kubernetes安装)
    1. [kubernetes相关服务安装](#kubernetes相关服务安装)
    1. [docker镜像导入](#docker镜像导入)
1. [第一台master初始化](#第一台master初始化)
    1. [独立etcd集群部署](#独立etcd集群部署)
    1. [kubeadm初始化](#kubeadm初始化)
    1. [flannel网络组件安装](#flannel网络组件安装)
    1. [dashboard组件安装](#dashboard组件安装)
    1. [heapster组件安装](#heapster组件安装)
    1. [验证第一台master安装](#验证第一台master安装)
1. [master集群高可用设置](#master集群高可用设置)
    1. [复制配置](#复制配置)
    1. [创建证书](#创建证书)
    1. [修改配置](#修改配置)
    1. [验证高可用安装](#验证高可用安装)
    1. [keepalived安装配置](#keepalived安装配置)
    1. [nginx负载均衡配置](#nginx负载均衡配置)
    1. [验证master集群高可用](#验证master集群高可用)
1. [node节点加入高可用集群设置](#node节点加入高可用集群设置)
    1. [kubeadm加入高可用集群](#kubeadm加入高可用集群)
    1. [部署应用验证集群](#部署应用验证集群)
    

### 部署架构

#### 概要部署架构

![ha logo](images/ha.svg)


---
[返回目录](#目录)

#### 详细部署架构

---
[返回目录](#目录)

#### 主机节点清单

---
[返回目录](#目录)

### 安装前准备

#### 版本信息

---
[返回目录](#目录)

#### 所需docker镜像

---
[返回目录](#目录)

#### 系统设置

---
[返回目录](#目录)

### kubernetes安装

#### kubernetes相关服务安装

---
[返回目录](#目录)

#### docker镜像导入

---
[返回目录](#目录)

### 第一台master初始化

#### 独立etcd集群部署

---
[返回目录](#目录)

#### kubeadm初始化

---
[返回目录](#目录)

#### flannel网络组件安装

---
[返回目录](#目录)

#### dashboard组件安装

---
[返回目录](#目录)

#### heapster组件安装

---
[返回目录](#目录)

#### 验证第一台master安装

---
[返回目录](#目录)

### master集群高可用设置

#### 复制配置

---
[返回目录](#目录)

#### 创建证书

---
[返回目录](#目录)

#### 修改配置

---
[返回目录](#目录)

#### 验证高可用安装

---
[返回目录](#目录)

#### keepalived安装配置

---
[返回目录](#目录)

#### nginx负载均衡配置

---
[返回目录](#目录)

#### 验证master集群高可用

---
[返回目录](#目录)

### node节点加入高可用集群设置

#### kubeadm加入高可用集群

---
[返回目录](#目录)

#### 部署应用验证集群

---
[返回目录](#目录)

