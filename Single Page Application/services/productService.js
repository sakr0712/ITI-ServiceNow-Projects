var app = angular.module("myApp");

app.service("productService", function ($http) {
          const API_URL =
            "https://69a69040feb94223b31d9d13.mockapi.io/products";

          this.getProducts = function () {
            return $http.get(API_URL);
          };

          this.createProduct = function (product) {
            return $http.post(API_URL, product);
          };

          this.updateProduct = function (product) {
            return $http.put(API_URL + "/" + product.id, product);
          };

          this.deleteProduct = function (id) {
            return $http.delete(API_URL + "/" + id);
          };
        })
