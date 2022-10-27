import $ from 'jquery';
import THREE from 'three/build/Three';
import './three-objloader';
import TweenMax from 'gsap/TweenMax';

/*
  Copyright (c) 2022 by Mark Mankarious (https://codepen.io/markmanx01/pen/MePEPa)

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

window.Utils = {};

Utils.toRad = function(deg) {
	return (Math.PI / 180) * deg;
}

Utils.toDeg = function(rad) {
	return (180 / Math.PI) * rad;
}

Utils.rnd = function(min, max) {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

Utils.unproject2DCoords = function(x, y, camera, targetZ) {
	var tZ = targetZ || 0;
	var vec3 = new THREE.Vector3( (x / window.innerWidth) * 2 - 1, -(y / window.innerHeight) * 2 + 1, 0.5 );
	vec3.unproject(camera);
	var dir = vec3.sub(camera.position).normalize();
	var distance = (tZ - camera.position.z) / dir.z;
	var pos = camera.position.clone().add( dir.multiplyScalar( distance ) );

	return pos;
}

Utils.extend = function(arr1, arr2) {
  for(var key in arr2)
      if(arr2.hasOwnProperty(key))
          arr1[key] = arr2[key];
  return arr1;
}

TweenMax.rotateTo = function(obj3d, duration, params) {
	var currQ = obj3d.quaternion;
	var m = new THREE.Matrix4();
	m.lookAt( params.vector, obj3d.position, obj3d.up );
	var newQuat = currQ.clone().setFromRotationMatrix(m);

	var tweenParams = Utils.extend({
		x: newQuat.x,
		y: newQuat.y,
		z: newQuat.z,
		w: newQuat.w
	}, params);

	return TweenMax.to(currQ, duration, tweenParams);
}

Utils.loadOBJ = function(objFile, mtlFile, onReady) {
	var materials;

	if (mtlFile !== null) {
		var mtlLoader = new THREE.MTLLoader();

		mtlLoader.load(mtlFile, function(_mats) {
			_mats.preload();
			materials = _mats;
			loadModel();
		});
	} else {
		loadModel();
	}

	function loadModel() {
		var objLoader = new THREE.OBJLoader();
		if (materials) objLoader.setMaterials( materials );
		objLoader.load( objFile, function ( object ) {
			onReady && onReady(object);
		});
	}
}

const setupWatcher = function(window) {

	function Watcher(camera, onReady) {
    this.onReady = onReady;
		this.camera = camera;
		this.mouseX = 0;
		this.mouseY = 0;
		this.walkerY = 0;
		this.walkerX = 0;
		this.loaded = false;

		var self = this;

		this.el = new THREE.Object3D();
		var scale = 1.2;
		this.el.scale.set(scale, scale, scale);

		setTimeout(function() {
			var vec3 = Utils.unproject2DCoords(window.innerWidth / 2, window.innerHeight * 2 / 3, camera, 5);
			this.el.position.set(vec3.x, vec3.y, 10);
		}.bind(this), 0)


		// Load OBJ File with Materials
		Utils.loadOBJ('https://s3-us-west-2.amazonaws.com/s.cdpn.io/356608/cam.obj', 'https://s3-us-west-2.amazonaws.com/s.cdpn.io/356608/cam.mtl', function(object) {
			var body = new THREE.Object3D(),
					base = new THREE.Object3D(),
					pivot = new THREE.Object3D();

			// Apply shadows
			object.traverse( function(child) {
				if ( child instanceof THREE.Mesh ) {
	        child.castShadow = true;
	        child.receiveShadow = true;
		    }
			})

      var glass = object.getObjectByName('Glass');
      glass.material = new THREE.MeshPhongMaterial({color: 'black', shininess: 300, reflectivity: 10, opacity: 0.7});
      glass.material.transparent = true;

			// Separate parts of the camera into groups
			body.add(object.getObjectByName('lens_body'));
      body.add(object.getObjectByName('Glass'));
			body.add(object.getObjectByName('cam_body'));
			body.add(object.getObjectByName('rotate_node02'));
			body.add(object.getObjectByName('lens01'));
			body.add(object.getObjectByName('rain_cover'));
			base.add(object.getObjectByName('cam_base'));
			pivot.add(object.getObjectByName('Rotate_node_Z'));

			self.body = body;
			self.base = base;
			self.pivot = pivot;

			self.el.add(body);
			self.el.add(base);
			self.el.add(pivot);

			self.loaded = true;
			self.onReady();
		});

		document.addEventListener('mousemove', this.onMouseMove.bind(this));
	}

  Watcher.prototype.onMouseMove = function(e) {
    this.mouseX = e.clientX;
		this.mouseY = e.clientY;

    var vec3 = Utils.unproject2DCoords(this.mouseX, this.mouseY, this.camera, 10).sub(new THREE.Vector3(this.el.position.x - 2, this.el.position.y + 2, 0));
		TweenMax.rotateTo(this.body, 0.1, {vector: vec3, ease: Linear.easeNone, delay: 0.2});
  }

	window.Watcher = Watcher;
};

setupWatcher(window);


var wW,
		wH,
		canvas3d,
		canvas2d,
		scene,
		camera,
		renderer,
		watcher,
		lights = [],
		plane,
    numObjectsLoaded = 0;

function init() {
	const toReplace = $('img.logo');

	wW = toReplace.width() * 2;
	wH = toReplace.height() * 2;

  console.log('wW/wH', `${wW}/${wH}`);


  // if (canvas3d) {
  //   canvas3d.style.width = wW + 'px';
  //   canvas3d.style.height = wH + 'px';
  // }

  // $('#intro').css({
  //   left: (wW / 2) - ($('#intro').width() / 2),
  //   top: (wH / 2) - ($('#intro').height() / 2)
  // })

	// Set up 3D Canvas
	scene = new THREE.Scene();
	camera = new THREE.PerspectiveCamera(40, wW / wH, 0.1, 1000);
	camera.position.z = 20;
	camera.lookAt(scene.position);
	renderer = new THREE.WebGLRenderer({
    canvas: canvas3d,
    antialias: true,
    alpha: true
  });
  renderer.setSize(toReplace.width()*2, toReplace.height()*2);
	renderer.shadowMap.enabled = true;

  // FIXME only replace when possible
  toReplace.replaceWith(renderer.domElement);

  watcher = new Watcher(camera, checkReady);
	scene.add(watcher.el);

	var light = new THREE.SpotLight(0xffffff);
	var vec3 = Utils.unproject2DCoords(window.innerWidth / 3, window.innerHeight / 3, camera, 5);
	light.position.set(vec3.x + 10, vec3.y + 20, 25);
	light.castShadow = true;
	light.shadow.mapSize.width = 4096;
	light.shadow.mapSize.height = 4096;
	light.shadow.camera.near = 1;
	light.shadow.camera.far = 200;
	light.shadow.camera.fov = 45;
	scene.add(light);

	var light2 = new THREE.AmbientLight(0xffffff, 0.3);
	scene.add(light2);

	var planeG = new THREE.PlaneGeometry(500, 500, 50);
	var planeMat = new THREE.MeshPhongMaterial({color: 0x333, side: THREE.DoubleSide});
	plane = new THREE.Mesh(planeG, planeMat);
	plane.receiveShadow = true;
	// scene.add(plane);

	light.lookAt(watcher.el.position);

	render();
}

function checkReady() {
  numObjectsLoaded++;
  console.log(numObjectsLoaded)
  if (numObjectsLoaded >= 2) {
    TweenLite.to('#intro, #bg', 1, {opacity: 0});
  }
}

function render() {
	requestAnimationFrame(render);
	renderer.render(scene, camera);
}

$(document).ready(init);
