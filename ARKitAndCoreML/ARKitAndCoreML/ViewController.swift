//
//  ViewController.swift
//  ARKitAndCoreML
//
//  Created by 刘李斌 on 2017/11/27.
//  Copyright © 2017年 Brilliance. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    //拿到模型
//    var resentModel = Resnet50()
    var resentModel = SqueezeNet()
    
    //点击后拿到的结果
    var hitTestResult: ARHitTestResult!
    
    //分析的结果
    var visionRequests = [VNRequest]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
//        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        registerGestureRecognizers()
    }
    
    //创建一个手势
    func registerGestureRecognizers() {
        let tapGes = UITapGestureRecognizer(target: self, action: #selector(tapped))
        
        self.sceneView.addGestureRecognizer(tapGes)
    }
    
    @objc func tapped(recognizer: UIGestureRecognizer) {
        //当前画面的SceneView
        let sceneView = recognizer.view as! ARSCNView
        
        let touchLocation = self.sceneView.center
        
        //判断当前sceneView是否有像素, 防止画面全黑或者全白
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        //点击结果 - 识别物体的特征点
        let hitTestResults = sceneView.hitTest(touchLocation, types: .featurePoint)
        
        if hitTestResults.isEmpty {
            return
        }
        
        //防止重复点击, 只取第一次点击
        guard let hitTestResult = hitTestResults.first else { return }
        
        //拿到点击的结果
        self.hitTestResult = hitTestResult
        
        //拿到的图片转成像素, pixelBuffer的数据类型就是CVPixelBuffer
        let pixelBuffer = currentFrame.capturedImage
        performVisionRequest(pixelBuffer: pixelBuffer)
    }
    
    //对像素进行处理
    func performVisionRequest(pixelBuffer: CVPixelBuffer) {
        //调用MLModel
        let visionModel = try! VNCoreMLModel(for: self.resentModel.model)
        
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            if error != nil {
                return
            }
            //取结果
            guard let observations = request.results else {
                return
            }
            
            //把结果中的第一位拿出来进行分析
            //VNClassificationObservation 可以理解为模型中的黑匣子(类似于飞机中的黑匣子), 用来处理所有的运算结果
            let observation = observations.first as! VNClassificationObservation
            print("indetifier = \(observation.identifier) and confidence = \(observation.confidence)")
            
            DispatchQueue.main.async {
                self.displayPredictions(text: observation.identifier)
            }
        }
        
        //结果取出中间的区域(224 * 224)
        request.imageCropAndScaleOption = .centerCrop
        
        self.visionRequests = [request]
        
        //将拿到的结果左右翻转, upMirrored 镜像翻转
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored, options: [:])
        
        DispatchQueue.global().async {
            //处理所有的结果
            //这是一个耗时操作  需要放到子线程中
            try! imageRequestHandler.perform(self.visionRequests)
        }
    }
    
    //展示预测的结果
    func displayPredictions(text: String) {
        
        let node = creatText(text: text)
        
        //worldTransform - 是将现实世界的xyz轴转换为手机中的xyz轴
        node.position = SCNVector3(self.hitTestResult.worldTransform.columns.3.x, self.hitTestResult.worldTransform.columns.3.y, self.hitTestResult.worldTransform.columns.3.z)
        
        self.sceneView.scene.rootNode.addChildNode(node)
    }
    
    //制作结果  AR图标和结果
    func creatText(text: String) -> SCNNode {
        let parentNode = SCNNode()
        
        //底座 - 小球
        let sphere = SCNSphere(radius: 0.01)
        //小球的渲染器
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = UIColor.red
        sphere.firstMaterial = sphereMaterial
        //创建球状节点
        let sphereNode = SCNNode(geometry: sphere)
        parentNode.addChildNode(sphereNode)
        
        
        
        //文字 - 预测的结果
        let textGeo = SCNText(string: text, extrusionDepth: 0)
        textGeo.alignmentMode = kCAAlignmentCenter
        //字体颜色
        textGeo.firstMaterial?.diffuse.contents = UIColor.red
        //倒影颜色
        textGeo.firstMaterial?.specular.contents = UIColor.white
        //是够两面都能看
        textGeo.firstMaterial?.isDoubleSided = true
        //字体
        textGeo.font = UIFont(name: "Future", size: 0.01)
        
        let textNode = SCNNode(geometry: textGeo)
        //缩放
        textNode.scale = SCNVector3Make(0.01, 0.01, 0.01)
        
        textNode.position = SCNVector3(sphereNode.position.x - 0.1, sphereNode.position.y + 0.1, sphereNode.position.z)
        
        parentNode.addChildNode(textNode)
        
        return parentNode
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
