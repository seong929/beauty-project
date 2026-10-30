import 'dart:convert';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/storage_image.dart';
import 'package:beauty_project/model/customer/storage_product.dart';
import 'package:beauty_project/vm/customer/storage_product_handler.dart';
import 'package:beauty_project/view/customer/home/storage_product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

// Sales fixtures for independent search/sort widget tests. Firebase matching has separate tests.
List<Override> storageCatalogOverrides(List<HomeProduct> products) => [
  storageProductsProvider.overrideWithValue(
    AsyncData([
      for (final product in products)
        StorageProduct(
          image: CustomerStorageImage(
            bucket: 'fixture.firebasestorage.app',
            objectName: '${product.name}.png',
          ),
          type: product.category,
          linkedProduct: product,
        ),
    ]),
  ),
  customerStorageImageLoaderProvider.overrideWithValue(
    (_) => MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
      ),
    ),
  ),
];
