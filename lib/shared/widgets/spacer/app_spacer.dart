import 'package:flutter/material.dart';

enum SpacerDirection { vertical, horizontal }

SizedBox addSpacer(double space, {SpacerDirection direction = SpacerDirection.vertical}) {
  return direction == SpacerDirection.vertical ? SizedBox(height: space) : SizedBox(width: space);
}
