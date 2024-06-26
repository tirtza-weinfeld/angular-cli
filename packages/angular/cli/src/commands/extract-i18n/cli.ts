/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.dev/license
 */

import { ArchitectCommandModule } from '../../command-builder/architect-command-module';
import { CommandModuleImplementation } from '../../command-builder/command-module';

export default class ExtractI18nCommandModule
  extends ArchitectCommandModule
  implements CommandModuleImplementation
{
  multiTarget = false;
  command = 'extract-i18n [project]';
  describe = 'Extracts i18n messages from source code.';
  longDescriptionPath?: string | undefined;
}
