var app= angular.module('myApp', ['ngRoute']);
app.config(function($routeProvider){
    $routeProvider
    .when('/home',{
        templateUrl:'views/home.html', 
        // controller:'homeCtrl'
    })
    .when('/about',{
        templateUrl:'views/about.html',        
        controller:'aboutCtrl'
    })
    .when('/products',{
        templateUrl:'views/products.html',        
        controller:'productsCtrl'   
    })
    .when('/gallery',{
        templateUrl:'views/gallery.html',        
        controller:'galleryCtrl'
    })
    .when('/contact',{
        templateUrl:'views/contact.html',        
        controller:'contactCtrl'
    })
    .otherwise({
        redirectTo:'/home'
    });
});

app.controller('NavController', function($scope, $location) {
    $scope.isActive = function(path) {
        return $location.path() === path;
    };
});

// empty controllers for gallery and contact pages (future logic can be added)
app.controller('galleryCtrl', function($scope) {
    // gallery-specific behaviour can go here
});

app.controller('contactCtrl', function($scope) {
    // contact-specific behaviour can go here
});

