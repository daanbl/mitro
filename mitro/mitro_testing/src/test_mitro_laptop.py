#!/usr/bin/env python
from mitro_testing.utils import *
from mitro_testing import network, video, process, ros

def test_network():
    print '-'*80
    network_tests = []
    add_test(network_tests, network.ip, 'eth0', '10.10.14.2')
    add_test(network_tests, network.unconnected, 'wlan0')
    add_test(network_tests, network.ping, 'localhost')
    add_test(network_tests, network.ping, 'mitro-laptop')
    add_test(network_tests, network.ping, 'bob')
    add_test(network_tests, network.ping, 'www.google.com')
    add_test(network_tests, network.ping, 'root')
    group_test(network_tests)

def test_video():
    print '-'*80
    video_tests = []
    add_test(video_tests, video.device, '/dev/video1')
    add_test(video_tests, video.device, '/dev/video2')
    add_test(video_tests, video.device, '/dev/video3')
    add_test(video_tests, video.v4l_info, '/dev/video1', 'uvcvideo')
    add_test(video_tests, video.v4l_info, '/dev/video2', 'uvcvideo')
    add_test(video_tests, video.v4l_info, '/dev/video3', 'Dummy')
    group_test(video_tests)

def test_process():
    print '-'*80
    process_tests = []
    add_test(process_tests, process.running, 'multicam')
    add_test(process_tests, process.running, 'skype')
    group_test(process_tests)

def test_ros():
    print '-'*80
    ros_tests = []
    add_test(ros_tests, ros.roscore, )
    group_test(ros_tests)

if __name__ == '__main__':
    test_network()
    test_video()
    test_process()
    test_ros()
