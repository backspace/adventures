import $ from 'jquery';
import THREE from 'three';
import ShaderToon from './ShaderToon';

var camera, scene, renderer, mesh;
var group;


var pageX, pageY;

let canvasX, canvasY;
let maxRotationDistance;

init();
animate();

function init() {

  scene = new THREE.Scene();

  camera = new THREE.PerspectiveCamera(45, 1, 1, 10000);
  camera.position.z = 200;
  scene.add(camera);

  var outlineColour = 0x333333;

  var lineMaterial = new THREE.LineBasicMaterial({
    color: outlineColour,
    linewidth: 5
  });

  var fillMaterial = new THREE.MeshBasicMaterial({
    color: outlineColour,
    side: THREE.DoubleSide
  });

  var outlineMaterial = new THREE.MeshBasicMaterial({
    color: outlineColour,
    side: THREE.BackSide
  });


  var shape = new THREE.Geometry();
  shape.vertices.push(new THREE.Vector3(-25, 0, 100));
  shape.vertices.push(new THREE.Vector3(-25, -50, 100));
  shape.vertices.push(new THREE.Vector3(-50, -75, 100));

  var line = new THREE.Line(shape, lineMaterial);
  //scene.add(line);

  var curve = new THREE.EllipseCurve(0, 0, // ax, aY
    5, 5, // xRadius, yRadius
    0, 2 * Math.PI, // aStartAngle, aEndAngle
    false, // aClockwise
    0 // aRotation
  );

  var path = new THREE.Path(curve.getPoints(50));
  var geometry = path.createPointsGeometry(50);
  var anchor = new THREE.Line(geometry, fillMaterial);
  // anchor.position = shape.vertices[2].clone();
  // anchor.position.z = 0;
  // anchor.position.y -= 2.5;
  // anchor.position.x -= 2.5;
  //scene.add(anchor);


  var light = new THREE.DirectionalLight(0x666666);
  light.position.set(0.5, 0.5, 1);

  var pointLight = new THREE.PointLight(0xff3300);
  pointLight.position.set(0, 0, 100);
  scene.add(pointLight);

  var ambientLight = new THREE.AmbientLight(0xddd);
  scene.add(ambientLight);

  group = new THREE.Object3D();


  var shader = THREE.ShaderToon['toon1'];

  var u = THREE.UniformsUtils.clone(shader.uniforms);

  var vs = shader.vertexShader;
  var fs = shader.fragmentShader;

  var toonMaterial1 = new THREE.ShaderMaterial({
    uniforms: u,
    vertexShader: vs,
    fragmentShader: fs
  });

  toonMaterial1.uniforms.uDirLightPos.value = light.position;
  toonMaterial1.uniforms.uDirLightColor.value = light.color;

  toonMaterial1.uniforms.uAmbientLightColor.value = ambientLight.color;

  var cylinderHeight = 120;
  var cylinderWidth = 40;
  var lensProportion = 0.4;

  var cylinderGeometry = new THREE.CylinderGeometry(cylinderWidth, cylinderWidth, cylinderHeight, 50, 1);
  var cylinderMesh = new THREE.Mesh(cylinderGeometry, toonMaterial1);
  group.add(cylinderMesh);

  var cylinderOutlineMesh = new THREE.Mesh(cylinderGeometry, outlineMaterial);
  cylinderOutlineMesh.scale.multiplyScalar(1.05);
  group.add(cylinderOutlineMesh);

  var capGeometry = new THREE.CylinderGeometry(cylinderWidth, cylinderWidth, 1, 50, 1);
  var capMesh = new THREE.Mesh(capGeometry, outlineMaterial);
  capMesh.scale.multiplyScalar(1.05);
  group.add(capMesh);

  capMesh.position.y = cylinderHeight/2;

  var smallerCylinderWidth = cylinderWidth * 0.75;
  var smallerCylinderHeight = cylinderWidth * 0.5;
  var smallerCylinderGeometry = new THREE.CylinderGeometry(smallerCylinderWidth, smallerCylinderWidth, smallerCylinderHeight, 50, 1);
  var smallerCylinderMesh = new THREE.Mesh(smallerCylinderGeometry, toonMaterial1);
  smallerCylinderMesh.position.y = cylinderHeight/2;
  group.add(smallerCylinderMesh);

  var smallerCylinderOutlineMesh = new THREE.Mesh(smallerCylinderGeometry, outlineMaterial);
  smallerCylinderOutlineMesh.scale.multiplyScalar(1.05);
  group.add(smallerCylinderOutlineMesh);

  var smallerCapGeometry = new THREE.CylinderGeometry(smallerCylinderWidth, smallerCylinderWidth, 1, 50, 1);
  var smallerCapMesh = new THREE.Mesh(smallerCapGeometry, outlineMaterial);
  smallerCapMesh.scale.multiplyScalar(1.05);
  group.add(smallerCapMesh);

  smallerCapMesh.position.y = (cylinderHeight/2) + (smallerCylinderHeight/2);

  var lensGeometry = new THREE.CylinderGeometry(smallerCylinderWidth * lensProportion, smallerCylinderWidth * lensProportion, 1, 50, 1);
  var lensMesh = new THREE.Mesh(lensGeometry, fillMaterial);
  lensMesh.position.y = smallerCylinderHeight/2 + smallerCylinderMesh.position.y;
  group.add(lensMesh);

  scene.add(group);

  group.rotation.x = Math.PI/2;
  group.rotation.y = 0;

  renderer = new THREE.WebGLRenderer({alpha: true});

  const toReplace = $('img.logo');
  renderer.setSize(toReplace.width()*2, toReplace.height()*2);

  // FIXME only replace when possible
  toReplace.replaceWith(renderer.domElement);


  const canvas = $(renderer.domElement);
  const canvasOffset = canvas.offset();

  canvasX = canvasOffset.left + canvas.width()/2;
  canvasY = canvasOffset.top + canvas.height()/2;

  const windowWidth = window.innerWidth;
  const windowHeight = window.innerHeight;

  maxRotationDistance = Math.min(windowWidth - canvasX, windowHeight - canvasY);
}

function animate() {
  render();
}

function render() {
  var deltaProportion = 0.005;

	var width = window.innerWidth;
  var height = window.innerHeight;

  var x = pageX || width/2;
  var y = pageY || height/2;

  const xProportion = Math.max(Math.min(x/maxRotationDistance, 1), -1);
  const yProportion = Math.max(Math.min(y/maxRotationDistance, 1), -1);

  var zRotation =  -(Math.PI/2*xProportion - Math.PI/2) - Math.PI/2;
  var zDelta = (zRotation - group.rotation.z)*deltaProportion;

  const lastZ = group.rotation.z;
  group.rotation.z += zDelta;

  var xRotation = Math.PI/2*yProportion + Math.PI/2;
  var xDelta = (xRotation - group.rotation.x)*deltaProportion;

  const lastX = group.rotation.x;
  group.rotation.x += xDelta;

  if (Math.abs(group.rotation.z - lastZ) > 0.0001 || Math.abs(group.rotation.x - lastX) > 0.0001) {
    requestAnimationFrame(animate);
  }

  renderer.render(scene, camera);
}

$(() => {
	$(window).mousemove((e) => {
  	pageX = e.pageX;
    pageY = e.pageY;

    const canvas = $(renderer.domElement);
    const canvasOffset = canvas.offset();

    const canvasCentreX = canvasOffset.left + canvas.width()/2;
    const canvasCentreY = canvasOffset.top + canvas.height()/2;

    const windowWidth = window.innerWidth;
    const windowHeight = window.innerHeight;

    pageX -= canvasX;
    pageY -= canvasY;
    requestAnimationFrame(animate);
  })
})
