app.controller("productsCtrl", function ($scope, productService) {
          $scope.products = [];
          $scope.newProduct = {};
          $scope.isEdit = false;
          $scope.loading = false;
          $scope.errorMessage = "";

          $scope.loadProducts = function () {
            $scope.loading = true;
            $scope.errorMessage = "";

            productService.getProducts()
              .then(function (response) {
                $scope.products = response.data;
              })
              .catch(function () {
                $scope.errorMessage = "Error loading products";
              })
              .finally(function () {
                $scope.loading = false;
              });
          };

          $scope.loadProducts();

          $scope.addProduct = function () {
            productService.createProduct($scope.newProduct)
              .then(function () {
                $scope.loadProducts();
                $scope.newProduct = {};
              })
              .catch(function () {
                $scope.errorMessage = "Error adding product";
              });
          };

          $scope.editProduct = function (product) {
            $scope.isEdit = true;
            $scope.newProduct = angular.copy(product);
          };

          $scope.updateProduct = function () {
            productService.updateProduct($scope.newProduct)
              .then(function () {
                $scope.loadProducts();
                $scope.newProduct = {};
                $scope.isEdit = false;
              })
              .catch(function () {
                $scope.errorMessage = "Error updating product";
              });
          };

          $scope.deleteProduct = function (id) {
            if (!confirm("Confirm deletion...")) return;

            productService.deleteProduct(id)
              .then(function () {
                $scope.loadProducts();
              })
              .catch(function () {
                $scope.errorMessage = "Error deleting product";
              });
          };

          $scope.cancelEdit = function () {
            $scope.isEdit = false;
            $scope.newProduct = {};
          };
        });