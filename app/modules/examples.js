// Generated by CoffeeScript 1.3.3
(function() {

  define(function(require) {
    var examples;
    examples = [
      {
        "name": "basics",
        "content": " \n#Simple comment, yay!\nsphere = new Sphere\n  d: 100\n  $fn: 10\n  center: [-100,-25,0]\n  \ncube = new Cube\n  size: 25\n  center: [100,0,0]\n\ncylinder = new Cylinder\n  h:100\n  r:10\n  \n###\nComments blocks are done like this\n###  \ncone = new Cylinder\n  h:100\n  d1:25\n  d2:75\n  center:[100,0,0]\n\n#Don't forget to 'return' what you want to see rendered (api might change)\nreturn sphere.union(cube).union(cylinder).union(cone)"
      }, {
        "name": "shapes",
        "content": " \ncircle = new Circle\n  d:100\n  $fn:10\n\nrect = new Rectangle\n  size: [200,100]\n  center: [150,10]\n  d: 15\n  $fn: 10\n  \n \n\nshape1 = fromPoints([[0,0], [150,50], [0,-50]])\nshape = shape1.expand(15, 10)\n\nshape = shape.union circle\nshape = shape.union rect\n\n\nshape = shape.extrude\n  offset: [0, 0, 100]\n  twist:45\n  slices:10\n       \nreturn shape "
      }, {
        "name": "mix",
        "content": "#Yeah , we can use classes!\nclass Thingy\n  constructor: (@thickness=10, @pos=[0,0,0], @rot=[0,0,0]) ->\n  \n  render: =>\n    result = new CSG()\n    shape1 = fromPoints [[0,0], [150,50], [0,-50]]\n    shape = shape1.expand(20, 25)\n    shape = shape.extrude\n      offset:[0, 0, @thickness]\n      \n    cyl = new Cylinder\n      r:10\n      $fn:12\n      h:100\n      center:true\n    ###\n    this could have been written as:\n    cyl = new Cylinder(r:10, $fn:12, h:100, center:true)\n\n    ###\n    result = shape.subtract cyl\n    return result.translate(@pos).rotate(@rot).\n    color([1,0.5,0])\n\n#Here we create two new class instances\nthing = new Thingy(35)\nthing2 = new Thingy(25)\n\nres = thing.render().union(\n  thing2.render()\n  .mirroredX()\n    .color([0.2,0.5,0.6]))\n    \nres= res.rotateX(37)\nres= res.rotateZ(5)\nres= res.translate([0,0,100])\nreturn res"
      }
    ];
    return examples;
  });

}).call(this);
