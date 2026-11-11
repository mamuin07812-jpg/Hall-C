import path from 'node:path';
import { realpathSync } from 'node:fs';

export function assertConnectionFilesOutsideRepository(files, repositoryRoot) {
  const root = realpathSync(repositoryRoot);
  for (const file of files) {
    const actual = realpathSync(file);
    const relative = path.relative(root, actual);
    const inside = relative === '' || (!path.isAbsolute(relative) && relative !== '..' && !relative.startsWith(`..${path.sep}`));
    if (inside) throw new Error('secret-bearing connection files must be kept outside the repository');
  }
}
